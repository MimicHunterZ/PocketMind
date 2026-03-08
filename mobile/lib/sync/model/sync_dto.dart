/// Pull 响应体 DTO
class SyncPullResponse {
  /// 本批次最新的服务端版本号，客户端保存为新游标
  final int serverVersion;

  /// 是否还有更多数据（分页）
  final bool hasMore;

  /// 本次增量变更列表
  final List<SyncChangeDto> changes;

  const SyncPullResponse({
    required this.serverVersion,
    required this.hasMore,
    required this.changes,
  });

  factory SyncPullResponse.fromJson(Map<String, dynamic> json) {
    return SyncPullResponse(
      serverVersion: json['serverVersion'] as int,
      hasMore: json['hasMore'] as bool? ?? false,
      changes: (json['changes'] as List<dynamic>? ?? [])
          .map((e) => SyncChangeDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 单条变更 DTO（Pull 响应中的每个元素）
class SyncChangeDto {
  /// 实体类型：'note' | 'category'
  final String entityType;

  /// 业务实体 UUID
  final String uuid;

  /// 操作：'create' | 'update' | 'delete'
  final String operation;

  /// 服务端版本号
  final int serverVersion;

  /// 服务端 updatedAt（毫秒）—— LWW 裁决标准
  final int updatedAt;

  /// 实体完整字段 map（仅 create/update 有效）
  final Map<String, dynamic> payload;

  const SyncChangeDto({
    required this.entityType,
    required this.uuid,
    required this.operation,
    required this.serverVersion,
    required this.updatedAt,
    required this.payload,
  });

  factory SyncChangeDto.fromJson(Map<String, dynamic> json) {
    return SyncChangeDto(
      entityType: json['entityType'] as String,
      uuid: json['uuid'] as String,
      operation: json['operation'] as String,
      serverVersion: json['serverVersion'] as int,
      updatedAt: json['updatedAt'] as int,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Push 请求体 DTO
class SyncPushRequest {
  final List<SyncMutationDto> mutations;

  const SyncPushRequest({required this.mutations});

  Map<String, dynamic> toJson() => {
    'mutations': mutations.map((m) => m.toJson()).toList(),
  };
}

/// Push 单条变更 DTO
class SyncMutationDto {
  /// 客户端幂等键
  final String mutationId;
  final String entityType;
  final String entityUuid;
  final String operation;
  final int updatedAt;
  final Map<String, dynamic> payload;

  const SyncMutationDto({
    required this.mutationId,
    required this.entityType,
    required this.entityUuid,
    required this.operation,
    required this.updatedAt,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
    'mutationId': mutationId,
    'entityType': entityType,
    'entityUuid': entityUuid,
    'operation': operation,
    'updatedAt': updatedAt,
    'payload': payload,
  };
}

/// Push 响应体 DTO（单条变更结果）
class SyncPushResult {
  /// 对应客户端 mutationId
  final String mutationId;

  /// 是否被服务端接受
  final bool accepted;

  /// 服务端分配的版本号（accepted=true 时有效）
  final int? serverVersion;

  /// 是否为瞬时失败，客户端应保留 mutation 并重试。
  final bool retryable;

  /// 拒绝原因（accepted=false 时有效）
  final String? rejectReason;

  /// 409 冲突时服务端权威实体（用于客户端回滚）
  final Map<String, dynamic>? conflictEntity;

  const SyncPushResult({
    required this.mutationId,
    required this.accepted,
    this.serverVersion,
    this.retryable = false,
    this.rejectReason,
    this.conflictEntity,
  });

  factory SyncPushResult.fromJson(Map<String, dynamic> json) {
    return SyncPushResult(
      mutationId: json['mutationId'] as String,
      accepted: json['accepted'] as bool,
      serverVersion: json['serverVersion'] as int?,
      retryable: json['retryable'] as bool? ?? false,
      rejectReason: json['rejectReason'] as String?,
      conflictEntity: json['conflictEntity'] as Map<String, dynamic>?,
    );
  }
}
