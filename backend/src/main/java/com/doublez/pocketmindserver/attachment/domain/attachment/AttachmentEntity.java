package com.doublez.pocketmindserver.attachment.domain.attachment;

import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.beans.ConstructorProperties;
import java.util.Objects;
import java.util.UUID;

/**
 * 附件领域实体（图片/PDF/文件的元数据）
 */
@Getter
@EqualsAndHashCode(of = "uuid")
public class AttachmentEntity {

    private final UUID uuid;
    private final long userId;
    private final UUID noteUuid;

    private final AttachmentType type;
    private final String mime;
    /**
     * storage_key：本地相对路径（pocket_images/xxx.jpg）或 OSS key（uploads/userId/sha256.ext）
     * 由 storageType 区分解析方式
     */
    private String storageKey;
    private StorageType storageType;
    private final String sha256;
    private final Integer width;
    private final Integer height;
    private final AttachmentSource source;

    private long updatedAt;
    private boolean deleted;

    /**
     * 构造函数仅用于持久化反序列化 / 映射（由 MapStruct 调用）。
     */
    @ConstructorProperties({
            "uuid",
            "userId",
            "noteUuid",
            "type",
            "mime",
            "storageKey",
            "storageType",
            "sha256",
            "width",
            "height",
            "source",
            "updatedAt",
            "deleted"
    })
    public AttachmentEntity(UUID uuid,
                            long userId,
                            UUID noteUuid,
                            AttachmentType type,
                            String mime,
                            String storageKey,
                            StorageType storageType,
                            String sha256,
                            Integer width,
                            Integer height,
                            AttachmentSource source,
                            long updatedAt,
                            boolean deleted) {
        this.uuid = Objects.requireNonNull(uuid, "uuid");
        this.userId = userId;
        this.noteUuid = Objects.requireNonNull(noteUuid, "noteUuid");
        this.type = Objects.requireNonNull(type, "type");
        this.mime = mime;
        this.storageKey = Objects.requireNonNull(storageKey, "storageKey");
        this.storageType = storageType != null ? storageType : StorageType.LOCAL;
        this.sha256 = sha256;
        this.width = width;
        this.height = height;
        this.source = source != null ? source : AttachmentSource.USER;
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    public static AttachmentEntity create(UUID uuid, long userId, UUID noteUuid,
                                           AttachmentType type, String mime,
                                           String storageKey, StorageType storageType,
                                           String sha256, Integer width, Integer height,
                                           AttachmentSource source) {
        return new AttachmentEntity(
            uuid,
            userId,
            noteUuid,
            type,
            mime,
            storageKey,
            storageType,
            sha256,
            width,
            height,
            source,
            System.currentTimeMillis(),
            false
        );
    }

    public void promoteToServer(String serverStorageKey) {
        this.storageKey = serverStorageKey;
        this.storageType = StorageType.SERVER;
        this.updatedAt = System.currentTimeMillis();
    }

    public void promoteToOss(String ossKey) {
        this.storageKey = ossKey;
        this.storageType = StorageType.OSS;
        this.updatedAt = System.currentTimeMillis();
    }

    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }
}
