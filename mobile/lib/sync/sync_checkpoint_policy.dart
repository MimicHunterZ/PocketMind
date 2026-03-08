/// 同步游标策略。
///
/// 负责解释 checkpoint 的语义，避免各处散落魔法值判断。
abstract final class SyncCheckpointPolicy {
  /// `lastPulledVersion == 0` 表示从未成功完成过一次 Pull。
  static bool isInitialPullVersion(int? lastPulledVersion) {
    return (lastPulledVersion ?? 0) == 0;
  }
}
