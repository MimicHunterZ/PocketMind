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

    public static final String TYPE_TEXT = "TEXT";
    public static final String TYPE_TOOL_CALL = "TOOL_CALL";
    public static final String TYPE_TOOL_RESULT = "TOOL_RESULT";

    private final UUID uuid;
    private final long userId;
    private final UUID sessionUuid;
    /** 链表结构：指向上一条消息的 uuid，NULL = 链头 */
    private final UUID parentUuid;
    /** 消息类型：TEXT | TOOL_CALL | TOOL_RESULT */
    private final String messageType;
    private final ChatRole role;
    private String content;
    private final List<UUID> attachmentUuids;
    private long updatedAt;
    private boolean deleted;
    /** 消息评分：1=点赞，0=未评价，-1=点踩 */
    private int rating;
    /** 分支别名：AI 静默生成的 4-8 字命名，仅叶节点有值 */
    private String branchAlias;

    /**
     * 构造函数仅用于持久化反序列化 / 映射（由 MapStruct 调用）。
     */
    @ConstructorProperties({
            "uuid",
            "userId",
            "sessionUuid",
            "parentUuid",
            "messageType",
            "role",
            "content",
            "attachmentUuids",
            "updatedAt",
            "deleted",
            "rating",
            "branchAlias"
    })
    public ChatMessageEntity(UUID uuid,
                             long userId,
                             UUID sessionUuid,
                             UUID parentUuid,
                             String messageType,
                             ChatRole role,
                             String content,
                             List<UUID> attachmentUuids,
                             long updatedAt,
                             boolean deleted,
                             int rating,
                             String branchAlias) {
        this.uuid = Objects.requireNonNull(uuid, "uuid 不能为空");
        this.userId = userId;
        this.sessionUuid = Objects.requireNonNull(sessionUuid, "sessionUuid 不能为空");
        this.parentUuid = parentUuid;
        this.messageType = messageType != null ? messageType : TYPE_TEXT;
        this.role = Objects.requireNonNull(role, "role 不能为空");
        this.content = content != null ? content : "";
        this.attachmentUuids = attachmentUuids != null ? List.copyOf(attachmentUuids) : Collections.emptyList();
        this.updatedAt = updatedAt;
        this.deleted = deleted;
        this.rating = rating;
        this.branchAlias = branchAlias;
    }

    // 工厂方法

    /**
     * 新建普通文本消息（无父节点，即链头）。
     */
    public static ChatMessageEntity create(UUID uuid, long userId, UUID sessionUuid,
                                           ChatRole role, String content, List<UUID> attachmentUuids) {
        return create(uuid, userId, sessionUuid, null, role, content, attachmentUuids);
    }

    /**
         * 新建带 parentUuid 的消息（链式对话）。
     *
     * @param parentUuid     上一条消息 uuid（NULL = 链头）
     */
    public static ChatMessageEntity create(UUID uuid, long userId, UUID sessionUuid,
                           UUID parentUuid, ChatRole role, String content,
                           List<UUID> attachmentUuids) {
        return new ChatMessageEntity(
                uuid,
                userId,
                sessionUuid,
                parentUuid,
                "TEXT",
                role,
                content,
                attachmentUuids,
                System.currentTimeMillis(),
                false,
                0,
                null
        );
    }

        /**
         * 新建工具消息（TOOL_CALL / TOOL_RESULT）。
         * <p>
         * content 必须是 JSON 字符串，客户端可直接解析。
         */
        public static ChatMessageEntity createTool(UUID uuid,
                               long userId,
                               UUID sessionUuid,
                               UUID parentUuid,
                               String messageType,
                               ChatRole role,
                               String content) {
        return new ChatMessageEntity(
            uuid,
            userId,
            sessionUuid,
            parentUuid,
            messageType != null ? messageType : TYPE_TEXT,
            role,
            content,
            List.of(),
            System.currentTimeMillis(),
            false,
            0,
            null
        );
        }

    // 业务行为
    /** 软删除 */
    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }

    /** 更新 rating */
    public void updateRating(int rating) {
        this.rating = rating;
        this.updatedAt = System.currentTimeMillis();
    }

    /** 更新内容（编辑消息） */
    public void updateContent(String content) {
        this.content = content;
        this.updatedAt = System.currentTimeMillis();
    }

    /** 设置分支别名 */
    public void setBranchAlias(String alias) {
        this.branchAlias = alias;
        this.updatedAt = System.currentTimeMillis();
    }
}