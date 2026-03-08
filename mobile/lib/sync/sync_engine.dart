import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/providers/auth_providers.dart';
import 'package:pocketmind/sync/pull_coordinator.dart';
import 'package:pocketmind/sync/push_coordinator.dart';
import 'package:pocketmind/sync/sync_checkpoint_policy.dart';
import 'package:pocketmind/sync/sync_state_provider.dart';
import 'package:pocketmind/util/logger_service.dart';

/// 同步引擎 —— 统一调度 Pull/Push，是唯一的网络同步入口。
///
/// ## Single-Flight 并发锁
///
/// 内部维护 [_isPulling] + [_hasPendingKick] 两个状态位，
/// 实现「单飞 + 追尾」模式：
/// - 若当前正在同步：新触发仅设置 `_hasPendingKick=true`，不重复发起请求。
/// - 本轮同步完成后：若 `_hasPendingKick==true`，自动执行下一轮（最多 1 次追尾）。
/// 这确保任何时刻飞行中的 HTTP 请求数最多为 1，防止弱网雪崩。
///
/// ## 同步顺序：Pull-first
///
/// 1. Pull 增量（获取服务端最新状态，可提前消除本地 pending mutations）
/// 2. Push 本地变更（冲突概率更低）
///
/// ## 自适应轮询策略（由外部 SyncStateNotifier 管理 Timer）
///
/// | 应用状态 | Pull 间隔 |
/// | 前台活跃 | 30 秒 |
/// | 刚切回前台 | 立即一次 |
/// | Push 完成后 | 立即一次 |
/// | 断网 | 停止，恢复后立即触发 |
class SyncEngine {
  final PullCoordinator _pullCoordinator;
  final PushCoordinator _pushCoordinator;
  final SyncStateNotifier _stateNotifier;
  final Ref _ref;

  static const String _tag = 'SyncEngine';

  bool _isPulling = false;
  bool _hasPendingKick = false;

  SyncEngine({
    required PullCoordinator pullCoordinator,
    required PushCoordinator pushCoordinator,
    required SyncStateNotifier stateNotifier,
    required Ref ref,
  }) : _pullCoordinator = pullCoordinator,
       _pushCoordinator = pushCoordinator,
       _stateNotifier = stateNotifier,
       _ref = ref;

  /// 触发一次同步。
  ///
  /// 遵循 Single-Flight 语义：
  /// - 若当前无同步任务 → 立即执行
  /// - 若当前正在同步 → 设置追尾标志，等当前轮完成后自动执行一次
  void kick() {
    if (_isPulling) {
      _hasPendingKick = true;
      PMlog.d(_tag, '同步中，已设置追尾 kick');
      return;
    }
    _doSync();
  }

  Future<void> _doSync() async {
    _isPulling = true;
    PMlog.d(_tag, '同步开始');

    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        PMlog.w(_tag, '未登录，跳过同步');
        return;
      }

      final lastPulledVersion = await _pullCoordinator.getLastPulledVersion(
        userId,
      );
      final isInitial = SyncCheckpointPolicy.isInitialPullVersion(
        lastPulledVersion,
      );
      if (isInitial) {
        _stateNotifier.setPhase(SyncPhase.initialPull);
      } else {
        _stateNotifier.setPhase(SyncPhase.pulling);
      }

      // 1. Pull first
      await _pullCoordinator.pull(userId);

      // 2. Push
      _stateNotifier.setPhase(SyncPhase.pushing);
      await _pushCoordinator.push();

      // 更新状态
      final failedCount = await _pushCoordinator.getFailedCount();
      final pendingCount = await _pushCoordinator.getPendingCount();
      _stateNotifier.onSyncComplete(
        failedCount: failedCount,
        pendingCount: pendingCount,
        lastSyncedAt: DateTime.now(),
      );

      PMlog.d(_tag, '同步完成，failed: $failedCount，pending: $pendingCount');
    } catch (e) {
      PMlog.e(_tag, '同步出错: $e');
      _stateNotifier.onSyncError(e.toString());
    } finally {
      _isPulling = false;
      // 追尾处理：若同步期间有新的 kick 请求，执行一次
      if (_hasPendingKick) {
        _hasPendingKick = false;
        PMlog.d(_tag, '执行追尾 kick');
        _doSync();
      }
    }
  }

  String? _getCurrentUserId() {
    try {
      final authState = _ref.read(authControllerProvider);
      return authState.userId;
    } catch (e) {
      return null;
    }
  }
}
