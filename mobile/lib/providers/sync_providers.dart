import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/api/note_api_service.dart';
import 'package:pocketmind/api/sync_api_service.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/providers/auth_providers.dart';
import 'package:pocketmind/providers/http_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/pm_service_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/data/repositories/isar_category_repository.dart';
import 'package:pocketmind/sync/local_write_coordinator.dart';
import 'package:pocketmind/sync/pull_coordinator.dart';
import 'package:pocketmind/sync/push_coordinator.dart';
import 'package:pocketmind/sync/resource_fetch_scheduler.dart';
import 'package:pocketmind/sync/sync_engine.dart';
import 'package:pocketmind/sync/sync_state_provider.dart';
import 'package:pocketmind/util/logger_service.dart';

part 'sync_providers.g.dart';

// ======================== 基础设施 Provider ========================

/// IsarCategoryRepository Provider
@Riverpod(keepAlive: true)
IsarCategoryRepository categoryRepository(Ref ref) {
  final isar = ref.watch(isarProvider);
  return IsarCategoryRepository(isar);
}

/// SyncApiService Provider
@Riverpod(keepAlive: true)
SyncApiService syncApiService(Ref ref) {
  final client = ref.watch(httpClientProvider);
  return SyncApiService(client);
}

/// LocalWriteCoordinator Provider —— 所有业务写操作的原子双写入口
@Riverpod(keepAlive: true)
LocalWriteCoordinator localWriteCoordinator(Ref ref) {
  final isar = ref.watch(isarProvider);
  return LocalWriteCoordinator(isar);
}

/// PullCoordinator Provider
@Riverpod(keepAlive: true)
PullCoordinator pullCoordinator(Ref ref) {
  final isar = ref.watch(isarProvider);
  final syncApi = ref.watch(syncApiServiceProvider);
  return PullCoordinator(isar: isar, syncApi: syncApi);
}

/// PushCoordinator Provider
@Riverpod(keepAlive: true)
PushCoordinator pushCoordinator(Ref ref) {
  final isar = ref.watch(isarProvider);
  final syncApi = ref.watch(syncApiServiceProvider);
  return PushCoordinator(isar: isar, syncApi: syncApi);
}

/// SyncEngine Provider —— 同步引擎唯一实例
@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref) {
  final pull = ref.watch(pullCoordinatorProvider);
  final push = ref.watch(pushCoordinatorProvider);
  final stateNotifier = ref.read(syncStateProvider.notifier);
  return SyncEngine(
    pullCoordinator: pull,
    pushCoordinator: push,
    stateNotifier: stateNotifier,
    ref: ref,
  );
}

/// ResourceFetchScheduler Provider —— 端侧元数据抓取调度器。
///
/// **重要**：本 provider 仅负责**实例化**调度器，不会自动调 `start()`。
///
/// 原因：本 provider 在三个 isolate 里都可能被实例化（主 App / 分享 /
/// Workmanager 后台任务）。`start()` 会立刻 unawaited 发射一发 runNow，
/// 在后台 isolate 里这会与 dispatcher 的显式 `await runNow()` 形成
/// "前者占位 → 后者 skip → dispatcher 立即返回 → Android 杀 isolate →
/// 前者半路被砍"的链条，导致抓取根本跑不完。
///
/// 因此：
///   - 主 App：`main.dart` 显式调用 `scheduler.start()` 一次（订阅
///     connectivity + 立即扫描一次）；
///   - Workmanager dispatcher：仅 `await scheduler.runNow(...)`；
///   - 分享 isolate：不使用本 provider。
@Riverpod(keepAlive: true)
ResourceFetchScheduler resourceFetchScheduler(Ref ref) {
  final isar = ref.watch(isarProvider);
  final noteService = ref.watch(noteServiceProvider);
  final metadataManager = ref.watch(metadataManagerProvider);
  final noteApi = ref.watch(noteApiServiceProvider);
  final assetApi = ref.watch(assetApiServiceProvider);
  final notification = ref.watch(notificationServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final scheduler = ResourceFetchScheduler(
    isar: isar,
    noteService: noteService,
    metadataManager: metadataManager,
    noteApiService: noteApi,
    assetApiService: assetApi,
    notificationService: notification,
    prefs: prefs,
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
}

// ======================== 自适应轮询调度器 ========================

/// 自适应轮询 Provider —— 根据应用状态自动调整 Pull 间隔。
///
/// 策略：
/// - 登录状态下每 30 秒触发一次 SyncEngine.kick()
/// - 网络状态变化时立即触发一次
/// - 该 Provider 为 keepAlive，App 生命周期内持续运行
@Riverpod(keepAlive: true)
void adaptiveSyncScheduler(Ref ref) {
  final engine = ref.watch(syncEngineProvider);
  final authState = ref.watch(authControllerProvider);

  // 未登录时不启动调度
  if (authState.userId == null) return;

  // 自适应定时器：前台活跃 30 秒间隔
  const interval = Duration(seconds: 30);
  Timer? timer;

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(interval, (_) {
      PMlog.d('SyncScheduler', '定时触发 kick');
      engine.kick();
    });
  }

  // 网络恢复立即触发
  final connectivitySub = Connectivity().onConnectivityChanged.listen((
    results,
  ) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork) {
      PMlog.d('SyncScheduler', '网络恢复，立即 kick');
      engine.kick();
    }
  });

  startTimer();
  // 启动时立即同步一次
  engine.kick();

  ref.onDispose(() {
    timer?.cancel();
    connectivitySub.cancel();
  });
}
