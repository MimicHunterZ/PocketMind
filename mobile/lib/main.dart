// ignore_for_file: unused_import

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:pocketmind/service/call_back_dispatcher.dart';
import 'package:pocketmind/service/notification_service.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/providers/auth_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/util/proxy_config.dart';
import 'package:pocketmind/util/quick_save_bridge.dart';
import 'package:pocketmind/util/storage_paths.dart';
import 'package:pocketmind/util/theme_data.dart';
import 'package:pocketmind/util/workmanager_platform_guard.dart';
import 'package:pocketmind/router/app_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import 'model/category.dart';
import 'model/note.dart';
import 'model/note_asset.dart';
import 'model/chat_session.dart';
import 'model/chat_message.dart';
import 'model/scrape_attempt.dart';
import 'sync/model/mutation_entry.dart';
import 'sync/model/sync_checkpoint.dart';
import 'data/repositories/isar_category_repository.dart';
import 'util/logger_service.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/category_providers.dart';
import 'package:pocketmind/providers/pm_service_providers.dart';
import 'package:pocketmind/providers/sync_providers.dart';

// 这会强制构建系统将 main_share.dart 编译到应用中
// 防止另一个入口没有被引用
import 'package:pocketmind/main_share.dart';

late Isar isar;

Future<void> main() async {
  // 确保 flutter 绑定初始化了
  WidgetsFlutterBinding.ensureInitialized();

  // 获取 SharedPreferences 实例用于 Provider
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

  // 获取一个可写目录（iOS 走 App Group 共享容器，其它平台保持 ApplicationDocuments）
  final dirPath = await getSharedContainerPath();
  // 打开 Isar 实例
  isar = await Isar.open([
    NoteSchema,
    CategorySchema,
    MutationEntrySchema,
    SyncCheckpointSchema,
    NoteAssetSchema,
    ChatSessionSchema,
    ChatMessageSchema,
    ScrapeAttemptSchema,
  ], directory: dirPath);

  // 确保初始化默认分类数据
  final categoryRepository = IsarCategoryRepository(isar);
  await categoryRepository.initDefaultCategories();

  await ImageStorageHelper().init();
  final notificationSvc = NotificationService();
  await notificationSvc.init();

  // 设置通知点击回调（前台时，用于点击通知本身，非 action 按钮）
  // action 按钮点击已在 NotificationService 内部处理
  notificationSvc.onNotificationTap = (payload, actionId) {
    // 仅处理点击通知本身的情况
    if (actionId == null && payload != null) {
      PMlog.d('Main', '通知被点击: $payload');
    }
  };

  // 仅移动端初始化 Workmanager，桌面端跳过避免缺少平台实现
  if (shouldInitializeWorkmanager(Platform.operatingSystem)) {
    await Workmanager().initialize(callbackDispatcher);
  }

  runApp(
    // 使用 ProviderScope 包裹应用，并 override isarProvider
    // 后续都使用状态管理里面的isar
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notificationSvc),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 确保自适应同步调度器始终激活
    ref.read(adaptiveSyncSchedulerProvider);

    // 激活 PENDING 笔记抓取调度器，并显式启动主 App 的常驻订阅
    // （订阅 connectivity 变化 + 启动时立即扫描一次）。
    // 注意：start() 不能放在 provider 工厂里，否则 Workmanager 后台 isolate
    // 也会触发，导致后台抓取被 isolate 生命周期提前砍断。详见
    // sync_providers.dart 上的注释与
    // docs/architecture/mobile/resource-fetch-pipeline.md。
    ref.read(resourceFetchSchedulerProvider).start();

    // 初始化鉴权
    ref.read(authControllerProvider);

    // 启动时再触发一轮 PENDING 笔记扫描（处理上次遗留 / 后台分享落地的 URL）；
    // start() 已经会发一次，这里相当于"用户体验侧"再保险触发，runNow 内部
    // 会用 in-flight Future 合流，不会重复扫描。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // iOS「保存到 PocketMind」快捷指令把 URL 暂存到 App Group 队列,
      // 这里先排空落库(PENDING),再触发抓取扫描,新存的链接才能被本轮扫到。
      await _drainQuickSave();
      // 把当前分类导出给快捷指令填写框「选分类」用。
      await QuickSaveBridge.exportCategories(ref.read(categoryServiceProvider));

      ref.read(resourceFetchSchedulerProvider).runNow();
      // 检查并轮询待处理的 AI 分析结果
      ref.read(aiPollingServiceProvider).pollAll();
    });
  }

  /// 排空 iOS 快捷指令队列(非 iOS 为 no-op)。
  Future<void> _drainQuickSave() async {
    await QuickSaveBridge.drainQuickSaveQueue(ref.read(noteServiceProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    PMlog.d('MyApp', 'AppLifecycleState changed: $state');
    if (state == AppLifecycleState.resumed) {
      PMlog.d('MyApp', 'App resumed, 触发 PENDING 扫描');
      // 先排空 iOS 快捷指令队列(回前台期间可能有新收藏),再走统一扫描入口。
      _drainQuickSave().whenComplete(() {
        // 单一调度入口：所有 PENDING 笔记由 ResourceFetchScheduler 接管,
        // CAS 互斥保证不会与后台 Workmanager 任务并发抓取同一 note。
        ref.read(resourceFetchSchedulerProvider).runNow();
      });
      ref.read(aiPollingServiceProvider).pollAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;

        final double designWidth = isDesktop ? 1280 : 400;
        final double designHeight = isDesktop ? 720 : 869;
        return ScreenUtilInit(
          designSize: Size(designWidth, designHeight),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'PocketMind',
            theme: calmBeigeTheme,
            darkTheme: quietNightTheme,
            themeMode: ThemeMode.system,
            routerConfig: appRouter,
          ),
        );
      },
    );
  }
}
