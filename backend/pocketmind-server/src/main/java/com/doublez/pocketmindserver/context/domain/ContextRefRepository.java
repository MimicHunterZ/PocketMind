package com.doublez.pocketmindserver.context.domain;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 上下文引用仓库接口 — 对应 context_ref 表。
 *
 * <p>管理业务对象（笔记/会话/消息/资产）与上下文 URI 的关联关系。
 */
public interface ContextRefRepository {

    /**
     * 保存新引用。
     */
    void save(ContextRefEntity entity);

    /**
     * 批量保存引用。
     */
    void saveBatch(List<ContextRefEntity> entities);

    /**
     * 按 contextUri + bizType 做 upsert（存在则更新 updatedAt，否则插入）。
     */
    void upsert(ContextRefEntity entity);

    /**
     * 按 contextUri 查找所有引用。
     */
    List<ContextRefEntity> findByContextUri(String contextUri, long userId);

    /**
     * 按 sessionUuid 查找该会话关联的所有引用。
     */
    List<ContextRefEntity> findBySessionUuid(UUID sessionUuid, long userId);

    /**
     * 按 noteUuid 查找该笔记关联的所有引用。
     */
    List<ContextRefEntity> findByNoteUuid(UUID noteUuid, long userId);

    /**
     * 按 uuid 查找引用。
     */
    Optional<ContextRefEntity> findByUuid(UUID uuid);

    /**
     * 逻辑删除指定引用。
     */
    void softDelete(UUID uuid);
}
