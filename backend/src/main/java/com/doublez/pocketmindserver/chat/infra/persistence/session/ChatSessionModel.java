package com.doublez.pocketmindserver.chat.infra.persistence.session;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@TableName("chat_sessions")
public class ChatSessionModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;
    private Long userId;
    private UUID scopeNoteUuid;
    private String title;
    private String memorySnapshot;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
