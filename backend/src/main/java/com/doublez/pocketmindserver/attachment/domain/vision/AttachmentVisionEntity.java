package com.doublez.pocketmindserver.attachment.domain.vision;

import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.beans.ConstructorProperties;
import java.util.Objects;
import java.util.UUID;

/**
 * 图片 AI 识别结果实体
 * 使图片内容能够被文本检索
 */
@Getter
@EqualsAndHashCode(of = "uuid")
public class AttachmentVisionEntity {

    private final UUID uuid;
    private final long userId;
    private final UUID attachmentUuid;

    private final String model;
    private String visionText;
    private String promptUsed;
    private VisionStatus status;

    private long updatedAt;
    private boolean deleted;

    /**
     * 构造函数仅用于持久化反序列化 / 映射（由 MapStruct 调用）。
     */
    @ConstructorProperties({
            "uuid",
            "userId",
            "attachmentUuid",
            "model",
            "visionText",
            "promptUsed",
            "status",
            "updatedAt",
            "deleted"
    })
    public AttachmentVisionEntity(UUID uuid,
                                  long userId,
                                  UUID attachmentUuid,
                                  String model,
                                  String visionText,
                                  String promptUsed,
                                  VisionStatus status,
                                  long updatedAt,
                                  boolean deleted) {
        this.uuid = Objects.requireNonNull(uuid, "uuid");
        this.userId = userId;
        this.attachmentUuid = Objects.requireNonNull(attachmentUuid, "attachmentUuid");
        this.model = Objects.requireNonNull(model, "model");
        this.visionText = visionText;
        this.promptUsed = promptUsed;
        this.status = status != null ? status : VisionStatus.PENDING;
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    public static AttachmentVisionEntity create(UUID uuid, long userId, UUID attachmentUuid, String model) {
        return new AttachmentVisionEntity(
                uuid,
                userId,
                attachmentUuid,
                model,
                null,
                null,
                VisionStatus.PENDING,
                System.currentTimeMillis(),
                false
        );
    }

    public void markDone(String visionText, String promptUsed) {
        this.visionText = Objects.requireNonNull(visionText, "visionText");
        this.promptUsed = promptUsed;
        this.status = VisionStatus.DONE;
        this.updatedAt = System.currentTimeMillis();
    }

    public void markFailed() {
        this.status = VisionStatus.FAILED;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 软删除（用于同步：客户端需要拿到删除事件）
     */
    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }
}
