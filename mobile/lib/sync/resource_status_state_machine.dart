import 'package:pocketmind/core/constants.dart';

/// Note.resourceStatus 的领域状态机。
///
/// 三个领域状态：
///   PENDING / CRAWLED / FAILED
///
/// 所有事件经此 reduce 推导下一状态，CRAWLED 是不可回退终态。
/// 执行层面（lease / 重试计数 / 进度）由 ScrapeAttempt 表承担，
/// 不在此处。
enum ResourceStatusEvent {
  /// 本地新建带 url 的笔记
  localCreatedWithUrl,

  /// 某次 ScrapeAttempt 成功结束
  attemptSucceeded,

  /// 抓取彻底失败（重试次数耗尽或硬失败），转 FAILED 终态
  attemptTerminallyFailed,

  /// 用户在 loading UI 上点"强制完成"，立即视作 FAILED
  userForceComplete,

  /// 用户在通知 / UI 上请求重试：FAILED → PENDING
  userRequestedRetry,

  /// 服务端推送来的 resourceStatus 快照（拉取合并时使用）
  serverSnapshot,
}

abstract final class ResourceStatusStateMachine {
  /// 推导下一状态，返回 null 表示"不变"。
  static String? reduce({
    required String? current,
    required ResourceStatusEvent event,
    String? incoming,
  }) {
    final normalizedCurrent = _normalize(current);
    final normalizedIncoming = _normalize(incoming);

    // CRAWLED 是不可回退终态：任何事件都不会改变它。
    if (normalizedCurrent == AppConstants.resourceStatusCrawled) {
      return AppConstants.resourceStatusCrawled;
    }

    switch (event) {
      case ResourceStatusEvent.localCreatedWithUrl:
        return AppConstants.resourceStatusPending;

      case ResourceStatusEvent.attemptSucceeded:
        return AppConstants.resourceStatusCrawled;

      case ResourceStatusEvent.attemptTerminallyFailed:
      case ResourceStatusEvent.userForceComplete:
        return AppConstants.resourceStatusFailed;

      case ResourceStatusEvent.userRequestedRetry:
        // FAILED / PENDING 都允许（重新）排队
        return AppConstants.resourceStatusPending;

      case ResourceStatusEvent.serverSnapshot:
        if (normalizedIncoming == null) return normalizedCurrent;
        // FAILED 仅允许被 CRAWLED 升级，其它快照不改
        if (normalizedCurrent == AppConstants.resourceStatusFailed &&
            normalizedIncoming != AppConstants.resourceStatusCrawled) {
          return AppConstants.resourceStatusFailed;
        }
        return normalizedIncoming;
    }
  }

  static String? _normalize(String? status) {
    if (status == null) return null;
    final value = status.trim();
    if (value.isEmpty) return null;
    switch (value) {
      case AppConstants.resourceStatusPending:
      case AppConstants.resourceStatusCrawled:
      case AppConstants.resourceStatusFailed:
        return value;
      default:
        // 未知/历史状态值一律按 PENDING 处理，避免脏数据卡死流水线。
        return AppConstants.resourceStatusPending;
    }
  }
}
