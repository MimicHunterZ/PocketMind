package com.doublez.pocketmindserver.sync.domain;

import com.doublez.pocketmindserver.sync.infra.persistence.SyncChangeLogModel;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 同步变更日志仓库接口（领域层定义，infra 层实现）。
 * <p>
 * {@code id}（AUTO_INCREMENT 主键）即为全局单调递增的 {@code serverVersion}。
 * </p>
 */
public interface SyncChangeLogRepository {

    /**
     * 原子性插入一条变更日志，返回生成的 id（即 serverVersion）。
     * <p>
     * 在同一 {@code @Transactional} 事务中被调用，与业务表的写入操作保持原子性。
     * </p>
     *
     * @param clientMutationId 客户端幂等键；AI/系统触发写入时传 {@code null}
     * @param payloadJson      实体完整 JSON 快照；delete 操作时传 {@code null}
     * @return 新插入行的 id（serverVersion）
     */
    long insert(long userId,
                String entityType,
                UUID entityUuid,
                String operation,
                long updatedAt,
                String clientMutationId,
                String payloadJson);

    /**
     * 幂等性校验：若该 mutationId 已存在则返回其对应的 serverVersion，否则返回 empty。
     */
    Optional<Long> findVersionByMutationId(String mutationId);

    /**
     * 增量 Pull 查询：返回 id > sinceVersion 的变更列表，按 id 升序排列。
     *
     * @param limit 最大返回行数（通常为 pageSize + 1，用于检测 hasMore）
     */
    List<SyncChangeLogModel> findSince(long userId, long sinceVersion, int limit);
}
