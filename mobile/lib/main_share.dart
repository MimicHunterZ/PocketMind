import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/model/note_asset.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/page/share/edit_note_page.dart';
import 'package:pocketmind/page/share/share_success_page.dart';
import 'package:pocketmind/page/widget/flowing_background.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/providers/auth_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/data/repositories/isar_category_repository.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/service/call_back_dispatcher.dart';
import 'package:pocketmind/service/category_service.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/sync/model/mutation_entry.dart';
import 'package:pocketmind/sync/model/sync_checkpoint.dart';
import 'package:pocketmind/sync/local_write_coordinator.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart'
    show IsarNoteRepository;
import 'package:pocketmind/service/notification_service.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/util/proxy_config.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketmind/util/url_helper.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'util/logger_service.dart';
import 'package:flutter_uri_to_file/flutter_uri_to_file.dart';

late Isar isar;
final String tag = 'main_share';

// UI 状态枚举
enum ShareUIState { waiting, success, editing }

// 关键：这是一个新的、独立的入口点
@pragma('vm:entry-point')
Future<void> mainShare() async {
  // 1. 初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 获取 SharedPreferences 实例
  final prefs = await SharedPreferences.getInstance();

  // 根据配置设置代理
  final proxyEnabled = prefs.getBool('proxy_enabled') ?? false;
  if (proxyEnabled) {
    final proxyHost = prefs.getString('proxy_host') ?? '127.0.0.1';
    final proxyPort = prefs.getInt('proxy_port') ?? 7890;
    HttpOverrides.global = GlobalHttpOverrides(
      '$proxyHost:$proxyPort',
      allowBadCertificates: true,
    );
  }

  final dir = await getApplicationDocumentsDirectory();

  // 2. 打开 Isar 实例,和主示例相同，要不然存的地方就不一样了
  isar = await Isar.open([
    NoteSchema,
    CategorySchema,
    NoteAssetSchema,
    ChatSessionSchema,
    ChatMessageSchema,
    MutationEntrySchema,
    SyncCheckpointSchema,
  ], directory: dir.path);

  final notificationSvc = NotificationService();
  await notificationSvc.init();

  await ImageStorageHelper().init();

  //开启后台进程
  await Workmanager().initialize(callbackDispatcher);

  // 4. 运行一个 只 包含分享 UI 的应用
  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        notificationServiceProvider.overrideWithValue(notificationSvc),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyShareApp(),
    ),
  );
}

class MyShareApp extends ConsumerStatefulWidget {
  const MyShareApp({super.key});
  @override
  ConsumerState<MyShareApp> createState() => _MyShareAppState();
}

class _MyShareAppState extends ConsumerState<MyShareApp>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.doublez.pocketmind/share');

  // UI 状态机
  ShareUIState _currentState = ShareUIState.waiting;
  ShareData? _currentShare;
  int _noteId = -1;
  String? url;

  // 非 final：热引擎第二次分享时需要重建
  late NoteService noteService;
  late CategoryService categoryService;

  @override
  void initState() {
    super.initState();
    // 初始化鉴权（恢复 token；无 token 时不影响功能）
    ref.read(authControllerProvider);
    _rebuildShareServices();
    _channel.setMethodCallHandler(_handleMethodCall);
    PMlog.d(tag, 'MyShareApp 初始化完成, 等待分享...');

    // 延迟通知原生端引擎已准备好
    // 使用 addPostFrameCallback 确保第一帧渲染完成后再通知
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyEngineReady();
    });
  }

  void _rebuildShareServices() {
    final prefs = ref.read(sharedPreferencesProvider);
    noteService = NoteService(
      noteRepository: IsarNoteRepository(isar),
      writeCoordinator: LocalWriteCoordinator(isar),
      prefs: prefs,
    );
    categoryService = CategoryService(
      categoryRepository: IsarCategoryRepository(isar),
      writeCoordinator: LocalWriteCoordinator(isar),
    );
  }

  /// 热引擎场景：Isar 已被 _dismissUI 关闭，重新打开并重建 NoteService。
  /// Providers 中的 isarProvider 是 keepAlive + overrideWithValue，运行时无法修改，
  /// 因此分享页链路统一使用手动构建的 service，避免复用已关闭的 Isar 引用。
  Future<void> _ensureReady() async {
    if (!isar.isOpen) {
      PMlog.d(tag, '检测到 Isar 已关闭，正在重新打开...');
      final dir = await getApplicationDocumentsDirectory();
      isar = await Isar.open([
        NoteSchema,
        CategorySchema,
        NoteAssetSchema,
        ChatSessionSchema,
        ChatMessageSchema,
        MutationEntrySchema,
        SyncCheckpointSchema,
      ], directory: dir.path);
      _rebuildShareServices();
      PMlog.d(tag, 'Isar 重新打开，分享页服务已重建');
    }
  }

  // 通知原生端 Flutter 引擎已准备好
  Future<void> _notifyEngineReady() async {
    try {
      await _channel.invokeMethod('engineReady');
      PMlog.d(tag, '已通知原生端：Flutter 引擎准备就绪');
    } catch (e) {
      PMlog.e(tag, '通知引擎准备就绪失败: $e');
    }
  }

  // 隐藏 UI 并关闭 Activity
  Future<void> _dismissUI([Map<String, String>? data]) async {
    // 重置状态机
    setState(() {
      _currentState = ShareUIState.waiting;
      _currentShare = null;
      _noteId = -1;
    });
    try {
      final userQuestion = data?['uq'];
      // 统一入口：分享场景与 App 回前台场景都通过 NoteService.processPendingUrls 调度
      await noteService.processPendingUrls(userQuestion: userQuestion);
    } catch (e) {
      PMlog.e(tag, 'processPendingUrls 失败，将继续关闭分享页');
    } finally {
      try {
        // 必须关闭，否则主 App 进入时 Isar 锁无法释放导致黑屏
        await isar.close();
        PMlog.d(tag, 'Isar (share) closed.');
      } catch (e) {
        PMlog.w(tag, 'Isar close fail: $e');
      }
    }
    // 关闭 ShareActivity
    SystemNavigator.pop();
  }

  // 状态转换：从 success 到 editing
  void _onAddDetailsClicked() {
    setState(() {
      _currentState = ShareUIState.editing;
    });
  }

  Future<String?> _extractedUrl(String content) async {
    if (UrlHelper.containsHttpsUrl(content)) {
      return UrlHelper.extractHttpsUrl(content);
    }
    if (UrlHelper.containsContentUri(content)) {
      String? uri = UrlHelper.extractContentUri(content);
      try {
        File tempFile = await toFile(uri!);
        // 先初始化一下
        await ImageStorageHelper().init();
        return await ImageStorageHelper().saveImage(tempFile);
      } catch (e) {
        PMlog.e(tag, '❌ URI 转换文件失败: $e');
      }
    }
    return null;
  }

  String? _contentWithoutUrl(String content) {
    return UrlHelper.removeUrls(content);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    PMlog.d(tag, '接收到方法: ${call.method}');

    switch (call.method) {
      case 'showShare':
        // 显示分享 UI
        final args = call.arguments as Map;
        final title = args['title'] as String;
        final content = _contentWithoutUrl(args['content'] as String);
        url = await _extractedUrl(args['content'] as String);

        PMlog.d(tag, 'showShare: title=$title, url=$url, content= $url');

        try {
          // 热引擎场景：确保 Isar 已打开
          await _ensureReady();

          // 1. 直接保存数据到数据库
          _noteId = await noteService.addNote(
            title: title,
            content: content,
            url: url,
          );

          if (url != null) {
            final added = await noteService.enqueuePendingUrlIfAbsent(url!);
            if (added) {
              PMlog.d(tag, '已保存到备份列表: needCallBackUrl');
            }
          }

          // 2. 更新 UI 状态以显示 ShareSuccessPage
          setState(() {
            _currentShare = ShareData(title: title, content: content, url: url);
            _currentState = ShareUIState.success;
          });

          PMlog.d(tag, '分享的UI成功展示');
          return 'Success';
        } catch (e) {
          PMlog.e(tag, '展示识别: $e');
          return e.toString();
        }

      default:
        throw PlatformException(
          code: 'Unimplemented',
          message: 'Unknown method ${call.method}',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: calmBeigeTheme,
        darkTheme: quietNightTheme,
        themeMode: ThemeMode.system,
        home: Material(
          type: MaterialType.transparency,
          child: _buildStage(context),
        ),
      ),
    );
  }

  // "舞台" - 统一的背景画布
  Widget _buildStage(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          // todo 这边还需要细调先这样吧
          color: Colors.black.withValues(alpha: 0.77),
        ),

        // --- 层 1: 流动的渐变背景 ---
        const FlowingBackground(),

        // --- 层 2: 实际页面内容 ---
        SafeArea(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: _buildTransition,
              child: _buildCurrentView(context),
            ),
          ),
        ),
      ],
    );
  }

  // 过渡动画构建器
  Widget _buildTransition(Widget child, Animation<double> animation) {
    // 判断是进入还是退出
    final isEntering = child.key == ValueKey(_currentState);

    if (_currentState == ShareUIState.editing || (child is EditNotePage)) {
      // EditNotePage: 从底部滑入
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: FadeTransition(opacity: animation, child: child),
      );
    } else if (_currentState == ShareUIState.success ||
        (child is ShareSuccessPage)) {
      // ShareSuccessPage: 向上飘散退出，淡入进入
      return SlideTransition(
        position:
            Tween<Offset>(
              begin: isEntering ? Offset.zero : const Offset(0, -0.2),
              end: isEntering ? Offset.zero : const Offset(0, -0.2),
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInCubic),
            ),
        child: FadeTransition(opacity: animation, child: child),
      );
    }

    // 默认：简单淡入淡出
    return FadeTransition(opacity: animation, child: child);
  }

  // 根据状态机构建当前视图
  Widget _buildCurrentView(BuildContext context) {
    switch (_currentState) {
      case ShareUIState.waiting:
        // 等待状态：透明占位
        return SizedBox.shrink(key: const ValueKey('waiting'));

      case ShareUIState.success:
        // 成功状态：显示成功页面
        return ShareSuccessPage(
          key: const ValueKey('success'),
          onDismiss: _dismissUI,
          onAddDetailsClicked: _onAddDetailsClicked,
        );

      case ShareUIState.editing:
        // 编辑状态：显示编辑页面
        return EditNotePage(
          key: const ValueKey('editing'),
          id: _noteId,
          initialTitle: _currentShare?.title ?? '',
          initialContent: _currentShare?.content ?? '',
          webUrl: _currentShare?.url,
          noteService: noteService,
          categoryService: categoryService,
          onDone: _dismissUI,
        );
    }
  }
}

class ShareData {
  final String? title;
  final String? content;
  final String? url;
  ShareData({required this.title, required this.content, this.url});
}
