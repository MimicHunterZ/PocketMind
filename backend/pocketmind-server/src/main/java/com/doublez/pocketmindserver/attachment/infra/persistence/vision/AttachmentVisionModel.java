package com.doublez.pocketmindserver.attachment.infra.persistence.vision;

import com.baomidou.mybatisplus.annotation.*;
import com.doublez.pocketmindserver.attachment.domain.vision.VisionStatus;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@TableName("asset_extractions")
public class AttachmentVisionModel {

    @TableId(type = IdType.AUTO)
    private Long id;

    private UUID uuid;
    private Long userId;
    private UUID assetUuid;
    private UUID noteUuid;
    private String contentType;
    private String content;
    private String model;
    private VisionStatus status;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    private Long updatedAt;

    @TableLogic
    private Boolean isDeleted;
}
