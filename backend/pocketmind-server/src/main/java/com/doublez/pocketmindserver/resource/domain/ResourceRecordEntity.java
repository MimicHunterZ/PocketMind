package com.doublez.pocketmindserver.resource.domain;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.beans.ConstructorProperties;
import java.util.Objects;
import java.util.UUID;

/**
 * AI 可读资源领域实体。
 */
@Getter
@EqualsAndHashCode(of = "uuid")
public class ResourceRecordEntity {

    private final UUID uuid;
    private final long userId;
    private final ResourceSourceType sourceType;
    private final ContextUri rootUri;
    private final UUID noteUuid;
    private final UUID sessionUuid;
    private final UUID assetUuid;
    private String title;
    private String content;
    private String sourceUrl;
    private long updatedAt;
    private boolean deleted;

    @ConstructorProperties({
            "uuid",
            "userId",
            "sourceType",
            "rootUri",
            "noteUuid",
            "sessionUuid",
            "assetUuid",
            "title",
            "content",
            "sourceUrl",
            "updatedAt",
            "deleted"
    })
    public ResourceRecordEntity(UUID uuid,
                                long userId,
                                ResourceSourceType sourceType,
                                ContextUri rootUri,
                                UUID noteUuid,
                                UUID sessionUuid,
                                UUID assetUuid,
                                String title,
                                String content,
                                String sourceUrl,
                                long updatedAt,
                                boolean deleted) {
        this.uuid = Objects.requireNonNull(uuid, "uuid 不能为空");
        this.userId = userId;
        this.sourceType = Objects.requireNonNull(sourceType, "sourceType 不能为空");
        this.rootUri = Objects.requireNonNull(rootUri, "rootUri 不能为空");
        this.noteUuid = noteUuid;
        this.sessionUuid = sessionUuid;
        this.assetUuid = assetUuid;
        this.title = title;
        this.content = content;
        this.sourceUrl = sourceUrl;
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    public static ResourceRecordEntity createNoteText(UUID uuid,
                                                      long userId,
                                                      UUID noteUuid,
                                                      ContextUri rootUri,
                                                      String title,
                                                      String content) {
        return new ResourceRecordEntity(
                uuid,
                userId,
                ResourceSourceType.NOTE_TEXT,
                rootUri,
                Objects.requireNonNull(noteUuid, "noteUuid 不能为空"),
                null,
                null,
                title,
                content,
                null,
                System.currentTimeMillis(),
                false
        );
    }

    public static ResourceRecordEntity createWebClip(UUID uuid,
                                                     long userId,
                                                     UUID noteUuid,
                                                     ContextUri rootUri,
                                                     String sourceUrl,
                                                     String title,
                                                     String content) {
        return new ResourceRecordEntity(
                uuid,
                userId,
                ResourceSourceType.WEB_CLIP,
                rootUri,
                Objects.requireNonNull(noteUuid, "noteUuid 不能为空"),
                null,
                null,
                title,
                content,
                sourceUrl,
                System.currentTimeMillis(),
                false
        );
    }

    public static ResourceRecordEntity createAssetText(UUID uuid,
                                                       long userId,
                                                       UUID assetUuid,
                                                       ContextUri rootUri,
                                                       String title,
                                                       String content) {
        return new ResourceRecordEntity(
                uuid,
                userId,
                ResourceSourceType.OCR_TEXT,
                rootUri,
                null,
                null,
                Objects.requireNonNull(assetUuid, "assetUuid 不能为空"),
                title,
                content,
                null,
                System.currentTimeMillis(),
                false
        );
    }

    public static ResourceRecordEntity createChatTranscript(UUID uuid,
                                                            long userId,
                                                            UUID sessionUuid,
                                                            ContextUri rootUri,
                                                            String title,
                                                            String content) {
        return new ResourceRecordEntity(
                uuid,
                userId,
                ResourceSourceType.CHAT_TRANSCRIPT,
                rootUri,
                null,
                Objects.requireNonNull(sessionUuid, "sessionUuid 不能为空"),
                null,
                title,
                content,
                null,
                System.currentTimeMillis(),
                false
        );
    }

    /**
     * 更新资源正文投影。
     */
    public void updateContent(String title, String content) {
        updateContent(title, content, this.sourceUrl);
    }

    /**
     * 更新资源正文投影，并在需要时刷新来源地址。
     */
    public void updateContent(String title, String content, String sourceUrl) {
        this.title = title;
        this.content = content;
        this.sourceUrl = sourceUrl;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 软删除资源。
     */
    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }
}
