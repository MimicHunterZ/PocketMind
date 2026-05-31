import 'package:isar_community/isar.dart';

part 'scrape_attempt.g.dart';

/// 抓取作业 + 历史记录。
///
/// 每一次"领走 → 跑 → 终结"都有一条 [ScrapeAttempt]。终态记录永久保留，
/// 用作失败可观测性的事实表。详见
/// `docs/architecture/mobile/resource-fetch-pipeline.md`。
///
/// 关键不变量：同一 [noteUuid] 下，[state] ∈ {queued, running} 的记录
/// 至多一条；终态（succeeded / failed / cancelled）行不可再变更。
@collection
class ScrapeAttempt {
  Id? id;

  /// 关联到 [Note.uuid]
  @Index()
  late String noteUuid;

  /// queued / running / succeeded / failed / cancelled
  ///
  /// 取值见 `AppConstants.scrapeAttemptState*`
  @Index()
  late String state;

  /// 同 noteUuid 下的第几次尝试（从 1 起算）
  late int attemptNumber;

  /// 入队时间
  late DateTime enqueuedAt;

  /// 被某 worker 领走的时间（running 状态下用于 lease 过期检测）
  DateTime? claimedAt;

  /// 终态时间
  DateTime? finishedAt;

  /// claim 这次尝试的进程标识（isolate 启动时生成的 UUID）
  String? claimedBy;

  /// 终态错误码（取值见 `AppConstants.scrapeError*`）
  String? errorCode;

  /// 给开发者看的失败详情，可空
  String? errorMessage;
}
