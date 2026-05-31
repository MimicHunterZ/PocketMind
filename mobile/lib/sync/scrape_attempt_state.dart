import 'package:pocketmind/core/constants.dart';

/// ScrapeAttempt 状态判定工具。
///
/// 状态机本身极简（每条记录最多两次写：queued → running → 终态），
/// 不需要复杂的事件 reduce。这里只暴露 `live` 集合，给 scheduler 在
/// claim / enqueue 去重时统一引用，避免到处散落字面量。
abstract final class ScrapeAttemptState {
  /// 活跃态：会出现在 claim 候选集中的状态。
  static const Set<String> live = {
    AppConstants.scrapeAttemptStateQueued,
    AppConstants.scrapeAttemptStateRunning,
  };
}
