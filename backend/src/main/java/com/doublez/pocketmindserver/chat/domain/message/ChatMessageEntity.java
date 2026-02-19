package com.doublez.pocketmindserver.chat.domain.message;

import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.beans.ConstructorProperties;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * 聊天消息领域实体
 */
@Getter
@EqualsAndHashCode(of = "uuid")
public class ChatMessageEntity {

    private final UUID uuid;
    private final long userId;
    private final UUID sessionUuid;
    private ChatRole role;
    private String content;
    private List<UUID> attachmentUuids;
    private long updatedAt;
    private boolean deleted;

    /**
     * 构造函数仅用于持久化反序列化 / 映射（由 MapStruct 调用）。
     */
    @ConstructorProperties({
            "uuid",
            "userId",
            "sessionUuid",
            "role",
            "content",
            "attachmentUuids",
            "updatedAt",
            "deleted"
    })
    public ChatMessageEntity(UUID uuid,
                             long userId,
                             UUID sessionUuid,
                             ChatRole role,
                             String content,
                             List<UUID> attachmentUuids,
                             long updatedAt,
                             boolean deleted) {
        this.uuid = Objects.requireNonNull(uuid, "uuid 不能为空");
        this.userId = userId;
        this.sessionUuid = Objects.requireNonNull(sessionUuid, "sessionUuid 不能为空");
        this.role = Objects.requireNonNull(role, "role 不能为空");
        this.content = Objects.requireNonNull(content, "content 不能为空");
        this.attachmentUuids = attachmentUuids != null ? List.copyOf(attachmentUuids) : Collections.emptyList();
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    // 工厂方法
    /** 新建消息（客户端传来 UUID） */
    public static ChatMessageEntity create(UUID uuid, long userId, UUID sessionUuid,
                                            ChatRole role, String content, List<UUID> attachmentUuids) {
        return new ChatMessageEntity(
            uuid,
            userId,
            sessionUuid,
            role,
            content,
            attachmentUuids,
            System.currentTimeMillis(),
            false
        );
    }

    // 业务行为
    /** 软删除 */
    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }
}