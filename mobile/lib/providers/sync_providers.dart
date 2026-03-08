import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/api/sync_api_service.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/providers/auth_providers.dart';
import 'package:pocketmind/providers/http_providers.dart';
import 'package:pocketmind/providers/note_providers.dart';
import 'package:pocketmind/providers/pm_service_providers.dart';
import 'package:pocketmind/data/repositories/isar_category_repository.dart';
import 'package:pocketmind/sync/local_write_coordinator.dart';
import 'package:pocketmind/sync/pull_coordinator.dart';
import 'package:pocketmind/sync/push_coordinator.dart';
import 'package:pocketmind/sync/resource_fetch_scheduler.dart';
import 'package:pocketmind/sync/sync_engine.dart';
import 'package:pocketmind/sync/sync_state_provider.dart';
import 'package:pocketmind/util/logger_service.dart';

part 'sync_providers.g.dart';

// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鍩虹璁炬柦 Provider 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

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

/// SyncEngine Provider 鈥斺€?鍚屾寮曟搸鍞竴瀹炰緥
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

/// ResourceFetchScheduler Provider 鈥斺€?绔晶鍏冩暟鎹姄鍙栬皟搴﹀櫒
@Riverpod(keepAlive: true)
ResourceFetchScheduler resourceFetchScheduler(Ref ref) {
  final noteRepo = ref.watch(noteRepositoryProvider);
  final metadataManager = ref.watch(metadataManagerProvider);
  final engine = ref.watch(syncEngineProvider);
  final scheduler = ResourceFetchScheduler(
    noteRepo: noteRepo,
    metadataManager: metadataManager,
    syncEngine: engine,
  );
  // 搴旂敤鍚姩鏃朵究寮€濮嬬洃鍚綉缁滀簨浠?
  scheduler.start();
  ref.onDispose(scheduler.dispose);
  return scheduler;
}

// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ 鑷€傚簲杞璋冨害鍣?鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

/// 鑷€傚簲杞 Provider 鈥斺€?鏍规嵁搴旂敤鐘舵€佽嚜鍔ㄨ皟鏁?Pull 闂撮殧銆?
///
/// 绛栫暐锛?
/// - 鐧诲綍鐘舵€佷笅姣?30 绉掕Е鍙戜竴娆?SyncEngine.kick()
/// - 缃戠粶鐘舵€佸彉鍖栨椂绔嬪嵆瑙﹀彂涓€娆?
/// - 姝?Provider keepAlive锛孉pp 鐢熷懡鍛ㄦ湡鍐呮寔缁繍琛?
@Riverpod(keepAlive: true)
void adaptiveSyncScheduler(Ref ref) {
  final engine = ref.watch(syncEngineProvider);
  final authState = ref.watch(authControllerProvider);

  // 鏈櫥褰曟椂涓嶅惎鍔ㄨ皟搴?
  if (authState.userId == null) return;

  // 鑷€傚簲瀹氭椂鍣細鍓嶅彴娲昏穬 30 绉掗棿闅?
  const interval = Duration(seconds: 30);
  Timer? timer;

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(interval, (_) {
      PMlog.d('SyncScheduler', '瀹氭椂瑙﹀彂 kick');
      engine.kick();
    });
  }

  // 缃戠粶鎭㈠绔嬪嵆瑙﹀彂
  final connectivitySub = Connectivity().onConnectivityChanged.listen((
    results,
  ) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork) {
      PMlog.d('SyncScheduler', '缃戠粶鎭㈠锛岀珛鍗?kick');
      engine.kick();
    }
  });

  startTimer();
  // 鍚姩鏃剁珛鍗冲悓姝ヤ竴娆?
  engine.kick();

  ref.onDispose(() {
    timer?.cancel();
    connectivitySub.cancel();
  });
}
