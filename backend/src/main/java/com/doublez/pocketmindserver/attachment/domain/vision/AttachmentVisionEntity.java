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
    private final UUID assetUuid;
    private final UUID noteUuid;

    private final String model;
    private final String contentType;
    private String content;
    private VisionStatus status;

    private long updatedAt;
    private boolean deleted;

    /**
     * 构造函数仅用于持久化反序列化 / 映射（由 MapStruct 调用）。
     */
    @ConstructorProperties({
            "uuid",
            "userId",
            "assetUuid",
            "noteUuid",
            "model",
            "contentType",
            "content",
            "status",
            "updatedAt",
            "deleted"
    })
    public AttachmentVisionEntity(UUID uuid,
                                  long userId,
                                  UUID assetUuid,
                                  UUID noteUuid,
                                  String model,
                                  String contentType,
                                  String content,
                                  VisionStatus status,
                                  long updatedAt,
                                  boolean deleted) {
        this.uuid = Objects.requireNonNull(uuid, "uuid");
        this.userId = userId;
        this.assetUuid = Objects.requireNonNull(assetUuid, "assetUuid");
        this.noteUuid = noteUuid;
        this.model = Objects.requireNonNull(model, "model");
        this.contentType = contentType != null ? contentType : "vision";
        this.content = content;
        this.status = status != null ? status : VisionStatus.PENDING;
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    public static AttachmentVisionEntity create(UUID uuid, long userId, UUID assetUuid, String model) {
        return new AttachmentVisionEntity(
                uuid,
                userId,
                assetUuid,
                null,
                model,
                "vision",
                null,
                VisionStatus.PENDING,
                System.currentTimeMillis(),
                false
        );
    }

    public void markDone(String content) {
        this.content = Objects.requireNonNull(content, "content");
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
