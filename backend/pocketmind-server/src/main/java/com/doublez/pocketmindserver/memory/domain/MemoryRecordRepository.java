package com.doublez.pocketmindserver.memory.domain;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 长期记忆领域仓储接口。
 */
public interface MemoryRecordRepository {

    /**
     * 保存记忆记录。
     */
    void save(MemoryRecordEntity entity);

    /**
     * 更新记忆记录。
     */
    void update(MemoryRecordEntity entity);

    /**
     * 根据 UUID 和用户 ID 查找记忆。
     */
    Optional<MemoryRecordEntity> findByUuidAndUserId(UUID uuid, long userId);

    /**
     * 查询指定用户的某类型记忆列表（按 updatedAt DESC + activeCount DESC 排序）。
     */
    List<MemoryRecordEntity> findByUserIdAndType(long userId, MemoryType memoryType, int limit);

    /**
     * 查询指定用户全部活跃记忆（按热度降序）。
     */
    List<MemoryRecordEntity> findActiveByUserId(long userId, int limit);

    /**
     * 根据 mergeKey 查找已有记忆（去重用）。
     */
    Optional<MemoryRecordEntity> findByMergeKey(long userId, MemoryType memoryType, String mergeKey);

    /**
     * 关键词搜索记忆（回退用，主检索路径走 searchByVector）。
     */
    List<MemoryRecordEntity> searchByKeyword(long userId, String keyword, MemoryType memoryType, int limit);

    /**
     * 递增 active_count。
     */
    void incrementActiveCount(UUID uuid);

    /**
     * 按用户分组统计各类型记忆数量。
     */
    List<MemoryTypeStat> countByUserGroupByType(long userId);

    /**
     * 向量相似度搜索记忆。
     *
     * @param queryVector 查询向量
     * @param userId      用户 ID
     * @param limit       最大返回数量
     * @return (entity, similarity) 对列表，按相似度降序
     */
    List<ScoredMemoryEntry> searchByVector(float[] queryVector, long userId, int limit);

    /**
     * 更新指定记忆的向量嵌入。
     */
    void updateEmbedding(UUID uuid, float[] embedding);

    /**
     * 记忆类型统计结果。
     */
    record MemoryTypeStat(MemoryType memoryType, long count) {}

    /**
     * 向量搜索结果条目。
     */
    record ScoredMemoryEntry(MemoryRecordEntity entity, double similarity) {}
}
