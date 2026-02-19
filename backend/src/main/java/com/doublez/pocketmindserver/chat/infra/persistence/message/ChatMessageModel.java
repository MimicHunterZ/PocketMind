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
    private ChatRole role;
    private String content;

    /**
     * PostgreSQL UUID[] — 存储为 TEXT[] 然后应用层自行转换
     * 简化处理：序列化为 JSON 字符串（或用自定义 TypeHandler）
     */
    @TableField(typeHandler = UuidArrayTypeHandler.class)
    private List<UUID> attachmentUuids;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
