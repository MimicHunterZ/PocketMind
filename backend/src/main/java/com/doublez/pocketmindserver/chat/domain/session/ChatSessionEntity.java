package com.doublez.pocketmindserver.chat.domain.session;

import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.beans.ConstructorProperties;
import java.util.Objects;
import java.util.UUID;

/**
 * 聊天会话领域实体
 */
@Getter
@EqualsAndHashCode(of = "uuid")
public class ChatSessionEntity {

    private final UUID uuid;
    private final long userId;
    /** 关联某条笔记（可选；null 表示全局对话） */
    private UUID scopeNoteUuid;
    private String title;
    /** 预留：持久记忆快照（暂不实现） */
    private String memorySnapshot;
    private long updatedAt;
    private boolean deleted;

    /**
     * 构造函数仅用于持久化反序列化 / 映射（由 MapStruct 调用）。
     */
    @ConstructorProperties({
            "uuid",
            "userId",
            "scopeNoteUuid",
            "title",
            "memorySnapshot",
            "updatedAt",
            "deleted"
    })
    public ChatSessionEntity(UUID uuid,
                             long userId,
                             UUID scopeNoteUuid,
                             String title,
                             String memorySnapshot,
                             long updatedAt,
                             boolean deleted) {
        this.uuid = Objects.requireNonNull(uuid, "uuid 不能为空");
        this.userId = userId;
        this.scopeNoteUuid = scopeNoteUuid;
        this.title = title;
        this.memorySnapshot = memorySnapshot;
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    // 工厂方法
    /** 新建会话（客户端传来 UUID） */
    public static ChatSessionEntity create(UUID uuid, long userId, UUID scopeNoteUuid, String title) {
        return new ChatSessionEntity(
                uuid,
                userId,
                scopeNoteUuid,
                title,
                null,
                System.currentTimeMillis(),
                false
        );
    }

    // 业务行为
    /** 修改会话标题 */
    public void updateTitle(String title) {
        this.title = title;
        this.updatedAt = System.currentTimeMillis();
    }

    /** 更新会话记忆快照 */
    public void updateMemorySnapshot(String memorySnapshot) {
        this.memorySnapshot = memorySnapshot;
        this.updatedAt = System.currentTimeMillis();
    }

    /** 软删除 */
    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }
}