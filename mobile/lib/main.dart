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
import 'package:pocketmind/util/theme_data.dart';
import 'package:pocketmind/router/app_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import 'model/category.dart';
import 'model/note.dart';
import 'lan_sync/model/sync_log.dart';
import 'data/repositories/isar_category_repository.dart';
import 'util/logger_service.dart';
import 'lan_sync/lan_sync_service.dart';
import 'package:pocketmind/providers/note_providers.dart';

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

  // 获取一个可写目录
  final dir = await getApplicationDocumentsDirectory();
  // 打开 Isar 实例
  isar = await Isar.open([
    NoteSchema,
    CategorySchema,
    SyncLogSchema,
  ], directory: dir.path);

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

  //开启后台进程
  await Workmanager().initialize(callbackDispatcher);

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
    // 触发 LanSyncService 初始化
    ref.read(lanSyncProvider);

    // 初始化鉴权
    ref.read(authControllerProvider);

    // 启动时检查是否有待处理的 URL 回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(noteServiceProvider).processPendingUrls();
    });
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
      PMlog.d('MyApp', 'App resumed, checking pending URLs');
      ref.read(noteServiceProvider).processPendingUrls();
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
