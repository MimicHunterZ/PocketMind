package com.doublez.pocketmindserver.attachment.infra.persistence.attachment;

import com.baomidou.mybatisplus.annotation.*;
import com.doublez.pocketmindserver.attachment.domain.attachment.AttachmentSource;
import com.doublez.pocketmindserver.attachment.domain.attachment.AttachmentType;
import com.doublez.pocketmindserver.attachment.domain.attachment.StorageType;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@TableName("assets")
public class AttachmentModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;
    private Long userId;
    private UUID noteUuid;
    private AttachmentType type;
    private String mime;
    private String storageKey;
    private StorageType storageType;
    private String sha256;
    private AttachmentSource source;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
