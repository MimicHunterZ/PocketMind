package com.doublez.pocketmindserver.chat.infra.persistence.message;

import com.baomidou.mybatisplus.annotation.*;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import lombok.Data;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Data
@TableName(value = "chat_messages", autoResultMap = true)
public class ChatMessageModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;
    private Long userId;
    private UUID sessionUuid;

    /** 链表结构：指向上一条消息的 uuid，NULL = 链头 */
    private UUID parentUuid;

    /** 消息类型：TEXT | TOOL_CALL | TOOL_RESULT */
    private String messageType;

    private ChatRole role;
    private String content;

    /**
     * PostgreSQL UUID[] — 使用自定义 TypeHandler 处理
     */
    @TableField(typeHandler = UuidArrayTypeHandler.class)
    private List<UUID> attachmentUuids;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;

    /** 消息评分：1=点赞，0=未评价，-1=点踩 */
    private Integer rating;

    /**
     * 分支别名：4-8 个中文字符，由 AI 自动生成，标记命名分支的叶节点。
     * 普通线性消息此字段为 null。
     */
    private String branchAlias;
}
