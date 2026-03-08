import 'package:isar_community/isar.dart';

part 'mutation_entry.g.dart';

/// 本地变更队列条目 —— Mutation Queue 的核心存储单元。
///
/// 每次业务实体发生写操作（create/update/delete）时，由 [LocalWriteCoordinator]
/// 在同一 Isar 事务中向此表追加一条记录，形成可靠的 WAL（预写日志）。
///
/// 网络恢复后，[PushCoordinator] 按 [id] 升序读取 status=pending 的条目，
/// 批量推送至后端，成功后标记为 synced。
@collection
class MutationEntry {
  /// Isar 自增主键，同时保证本地写入顺序（严格单调递增，即 Push 顺序）
  Id id = Isar.autoIncrement;

  /// 全局唯一幂等键（UUID v4），后端以此去重，防止重复推送
  @Index(unique: true)
  late String mutationId;

  /// 实体类型：'note' | 'category'
  late String entityType;

  /// 对应业务实体的 UUID，用于字段级合并时查找本地记录
  @Index()
  late String entityUuid;

  /// 操作类型：'create' | 'update' | 'delete'
  late String operation;

  /// 写入时刻的完整实体 JSON 快照（用于 Push payload）
  late String payload;

  /// 写入时的本地物理毫秒时间戳（对应 Note.updatedAt）
  late int updatedAt;

  /// 同步状态：0=pending / 1=pushing / 2=synced / 3=failed
  @Index()
  int status = MutationStatus.pending;

  /// 已重试次数，超过 [MutationStatus.maxRetries] 后置为 failed
  int retries = 0;

  /// 上次尝试推送的时间戳（毫秒）
  int? lastAttemptAt;

  /// 服务端永久拒绝时返回的原因（4xx 非 409），供 UI 展示"同步失败"角标
  String? failReason;
}

/// MutationEntry.status 枚举常量
abstract class MutationStatus {
  /// 待推送
  static const int pending = 0;

  /// 推送中（防止并发重复推送，crash 恢复时回退为 pending）
  static const int pushing = 1;

  /// 已同步
  static const int synced = 2;

  /// 永久失败（超过最大重试次数或服务端永久拒绝）
  static const int failed = 3;

  /// Push 最大重试次数，超出后置为 failed
  static const int maxRetries = 10;
}

/// MutationEntry.operation 枚举常量
abstract class MutationOperation {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
}

/// MutationEntry.entityType 枚举常量
abstract class MutationEntityType {
  static const String note = 'note';
  static const String category = 'category';
}
