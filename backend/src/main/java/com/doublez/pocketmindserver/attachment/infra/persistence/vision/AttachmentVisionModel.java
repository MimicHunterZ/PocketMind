package com.doublez.pocketmindserver.attachment.infra.persistence.vision;

import com.baomidou.mybatisplus.annotation.*;
import com.doublez.pocketmindserver.attachment.domain.vision.VisionStatus;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@TableName("attachment_visions")
public class AttachmentVisionModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;
    private Long userId;
    private UUID attachmentUuid;
    private String model;
    private String visionText;
    private String promptUsed;
    private VisionStatus status;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
