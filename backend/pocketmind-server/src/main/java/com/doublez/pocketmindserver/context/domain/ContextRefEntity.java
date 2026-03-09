package com.doublez.pocketmindserver.context.domain;

import java.util.Objects;
import java.util.UUID;

/**
 * 上下文引用实体 — 记录业务对象（笔记/会话/消息/资产）与上下文目录节点的关联关系。
 *
 * <p>用途：
 * <ul>
 *   <li>会话提交（commit）时，将会话关联到 Resource / Memory 节点</li>
 *   <li>笔记分析时，将笔记关联到相关上下文</li>
 *   <li>跨对象溯源 — 根据 contextUri 反查所有关联的业务对象</li>
 * </ul>
 *
 * <p>不持有数据库自增主键，可安全跨层传递。
 */
public record ContextRefEntity(
        UUID uuid,
        long userId,
        ContextUri contextUri,
        String bizType,
        String bizId,
        UUID noteUuid,
        UUID sessionUuid,
        UUID messageUuid,
        UUID assetUuid,
        String sourceUrl,
        long updatedAt,
        boolean deleted
) {

    public ContextRefEntity {
        Objects.requireNonNull(uuid, "ContextRefEntity.uuid 不能为空");
        Objects.requireNonNull(contextUri, "ContextRefEntity.contextUri 不能为空");
        Objects.requireNonNull(bizType, "ContextRefEntity.bizType 不能为空");
    }

    /**
     * 创建会话 → 资源的引用（SessionCommit 场景）。
     */
    public static ContextRefEntity ofSession(long userId,
                                             ContextUri contextUri,
                                             UUID sessionUuid,
                                             String bizType) {
        return new ContextRefEntity(
                UUID.randomUUID(),
                userId,
                contextUri,
                bizType,
                null,
                null,
                Objects.requireNonNull(sessionUuid, "sessionUuid 不能为空"),
                null,
                null,
                null,
                System.currentTimeMillis(),
                false
        );
    }

    /**
     * 创建笔记 → 上下文的引用。
     */
    public static ContextRefEntity ofNote(long userId,
                                          ContextUri contextUri,
                                          UUID noteUuid,
                                          String bizType) {
        return new ContextRefEntity(
                UUID.randomUUID(),
                userId,
                contextUri,
                bizType,
                null,
                Objects.requireNonNull(noteUuid, "noteUuid 不能为空"),
                null,
                null,
                null,
                null,
                System.currentTimeMillis(),
                false
        );
    }

    /**
     * 创建资产 → 上下文的引用。
     */
    public static ContextRefEntity ofAsset(long userId,
                                           ContextUri contextUri,
                                           UUID assetUuid,
                                           String bizType) {
        return new ContextRefEntity(
                UUID.randomUUID(),
                userId,
                contextUri,
                bizType,
                null,
                null,
                null,
                null,
                Objects.requireNonNull(assetUuid, "assetUuid 不能为空"),
                null,
                System.currentTimeMillis(),
                false
        );
    }
}
