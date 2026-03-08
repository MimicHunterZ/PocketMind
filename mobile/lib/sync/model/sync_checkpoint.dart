import 'package:isar_community/isar.dart';

part 'sync_checkpoint.g.dart';

/// 同步高水位线（Checkpoint）—— 持久化 Pull 游标。
///
/// 以服务端单调递增的 serverVersion 为游标，精确控制增量 Pull 范围。
/// 每次 Pull 成功后，将服务端返回的最新 serverVersion 写回此表。
///
/// 设计约束：
/// - 当且仅当完整处理完一批 Pull 响应后，才更新 lastPulledVersion，
///   防止中途崩溃导致数据空洞。
/// - 多账户场景下以 userId 为键隔离。
@collection
class SyncCheckpoint {
  /// 固定主键：每个用户只有一条记录，始终以 upsert 方式写入
  Id id = Isar.autoIncrement;

  /// 当前登录用户 ID，多账户切换时隔离游标
  @Index(unique: true)
  late String userId;

  /// 上次成功 Pull 的服务端版本号，初始为 0（触发全量拉取）
  int lastPulledVersion = 0;

  /// 最后一次成功同步的本地时间戳（毫秒）
  int lastSyncedAt = 0;
}
