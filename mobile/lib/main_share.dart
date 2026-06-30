import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/model/note_asset.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/scrape_attempt.dart';
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
import 'package:pocketmind/util/storage_paths.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:pocketmind/util/url_helper.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'util/logger_service.dart';
// flutter_uri_to_file 仅 Android 上有原生实现（解析 content:// URI）。
// iOS 上 Share Extension 通过 NSItemProvider.loadFileRepresentation 直接拿到
// 本地文件路径,因此 toFile() 调用必须用 Platform.isAndroid 守卫。
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

  final dirPath = await getSharedContainerPath();

  // 2. 打开 Isar 实例,和主示例相同，要不然存的地方就不一样了
  isar = await Isar.open([
    NoteSchema,
    CategorySchema,
    NoteAssetSchema,
    ChatSessionSchema,
    ChatMessageSchema,
    MutationEntrySchema,
    SyncCheckpointSchema,
    ScrapeAttemptSchema,
  ], directory: dirPath);

  final notificationSvc = NotificationService();
  await notificationSvc.init();

  await ImageStorageHelper().init();

  // 仅 Android 在分享 isolate 里也初始化 Workmanager,以便分享后能注册后台抓取任务。
  // iOS Share Extension 不需要也无法使用 Workmanager（系统不允许 Extension 注册 BGTask）。
  if (Platform.isAndroid) {
    await Workmanager().initialize(callbackDispatcher);
  }

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
    noteService = NoteService(
      noteRepository: IsarNoteRepository(isar),
      writeCoordinator: LocalWriteCoordinator(isar),
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
      final dirPath = await getSharedContainerPath();
      isar = await Isar.open([
        NoteSchema,
        CategorySchema,
        NoteAssetSchema,
        ChatSessionSchema,
        ChatMessageSchema,
        MutationEntrySchema,
        SyncCheckpointSchema,
        ScrapeAttemptSchema,
      ], directory: dirPath);
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
      // 分享 UI 关闭前注册一次后台抓取任务。
      // 真正的扫描在 callbackDispatcher → ResourceFetchScheduler.runNow() 中进行,
      // 因 share 进程会立刻关闭 Isar,无法在此 isolate 完成抓取。
      // ⚠️ iOS 上 Workmanager 不能从 Share Extension 注册 BGTask（系统限制）,
      // 改为留 PENDING：主 App 下次启动 / 前台时 ResourceFetchScheduler.runNow()
      // 会自动续抓（见 main.dart:140-144 / didChangeAppLifecycleState）。
      if (Platform.isAndroid) {
        await Workmanager().registerOneOffTask(
          'share_scrape_${DateTime.now().millisecondsSinceEpoch}',
          AppConstants.taskScrapeAndSave,
          inputData: <String, dynamic>{
            if (userQuestion != null && userQuestion.isNotEmpty)
              AppConstants.taskInputUserQuestion: userQuestion,
          },
          constraints: Constraints(networkType: NetworkType.connected),
        );
      }
    } catch (e) {
      PMlog.e(tag, '注册后台抓取任务失败,将继续关闭分享页: $e');
    } finally {
      try {
        // 必须关闭，否则主 App 进入时 Isar 锁无法释放导致黑屏
        await isar.close();
        PMlog.d(tag, 'Isar (share) closed.');
      } catch (e) {
        PMlog.w(tag, 'Isar close fail: $e');
      }
    }
    // 关闭分享 UI:
    //   Android: SystemNavigator.pop() 走 Flutter 默认路径关掉 ShareActivity
    //   iOS: 走 MethodChannel 通知 Swift 调 extensionContext.completeRequest
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod('dismissExtension');
      } catch (e) {
        PMlog.e(tag, 'dismissExtension 调用失败: $e');
      }
    } else {
      SystemNavigator.pop();
    }
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
    // content:// URI 仅 Android 系统分享会出现；iOS 上 Share Extension 通过
    // NSItemProvider.loadFileRepresentation 已经把图片落到本地路径,直接走
    // image/file 路径,不会走到这里。
    if (Platform.isAndroid && UrlHelper.containsContentUri(content)) {
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

          // 1. 直接保存数据到数据库（带 url 时 resourceStatus 自动置为 PENDING,
          //    后续由 ResourceFetchScheduler 在主 App 或 Workmanager 后台 isolate
          //    中经 CAS 领走作业并完成抓取）。本进程不需要再额外触发任何队列。
          _noteId = await noteService.addNote(
            title: title,
            content: content,
            url: url,
          );

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
