import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_state_provider.g.dart';

/// 同步阶段枚举
enum SyncPhase {
  /// 尚未开始，无活动
  idle,

  /// 初次拉取，应用启动后本地库可能为空，UI 显示骨架屏
  initialPull,

  /// 正在拉取
  pulling,

  /// 正在推送
  pushing,

  /// 同步出错，显示错误信息
  error,
}

/// 同步状态对象，供 UI 监听
class SyncState {
  /// 当前同步阶段
  final SyncPhase phase;

  /// pending 变更数量，网络未恢复时可为 0
  final int pendingCount;

  /// 失败的变更数量，用户可见错误标记
  final int failedCount;

  /// 最近一次成功同步的本地时间戳
  final DateTime? lastSyncedAt;

  /// 上一次错误信息（phase=error 时有效）
  final String? lastError;

  const SyncState({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  SyncState copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncedAt,
    String? lastError,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: lastError,
    );
  }

  /// 是否正在执行初始拉取，note_providers 会据此暂停观察
  bool get isInitialPull => phase == SyncPhase.initialPull;

  /// 是否存在失败的同步项
  bool get hasFailed => failedCount > 0;

  /// 是否正在同步
  bool get isSyncing =>
      phase == SyncPhase.pulling ||
      phase == SyncPhase.pushing ||
      phase == SyncPhase.initialPull;
}

/// 同步状态 Provider，供 SyncEngine 更新，UI 读取
/// 同步状态 Provider，SyncEngine直接调用其方法更新状态，UI 读取即可。
@Riverpod(keepAlive: true)
class SyncStateNotifier extends _$SyncStateNotifier {
  @override
  SyncState build() => const SyncState();

  /// SyncEngine 调用：设置当前阶段
  void setPhase(SyncPhase phase) {
    state = state.copyWith(phase: phase, lastError: null);
  }

  /// SyncEngine 调用：同步完成后更新统计数据
  void onSyncComplete({
    required int failedCount,
    required int pendingCount,
    required DateTime lastSyncedAt,
  }) {
    state = SyncState(
      phase: SyncPhase.idle,
      failedCount: failedCount,
      pendingCount: pendingCount,
      lastSyncedAt: lastSyncedAt,
    );
  }

  /// SyncEngine 调用：记录错误信息
  void onSyncError(String error) {
    state = state.copyWith(phase: SyncPhase.error, lastError: error);
  }
}

/// 仅暴露“是否处于首次拉取”派生状态，供 UI 做最小粒度监听。
@riverpod
bool syncIsInitialPull(Ref ref) {
  return ref.watch(syncStateProvider).isInitialPull;
}

/// 仅暴露“是否正在同步”派生状态，避免无关字段变更触发整块 UI 重建。
@riverpod
bool syncIsSyncing(Ref ref) {
  return ref.watch(syncStateProvider).isSyncing;
}
