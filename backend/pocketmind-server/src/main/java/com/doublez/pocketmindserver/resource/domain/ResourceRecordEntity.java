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
    private String abstractText;
    private String summaryText;
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
            "abstractText",
            "summaryText",
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
                                String abstractText,
                                String summaryText,
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
        this.abstractText = abstractText;
        this.summaryText = summaryText;
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
                null,
                null,
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
                null,
                null,
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
                null,
                null,
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
                null,
                null,
                content,
                null,
                System.currentTimeMillis(),
                false
        );
    }

    /**
     * 创建会话阶段摘要资源（L1 结构化概览）。
     *
     * @param abstractText L0 一句话摘要 (~100 token)
     * @param summaryText  L1 结构化概览 (~2k token)
     * @param content      L2 完整原始对话文本
     */
    public static ResourceRecordEntity createChatStageSummary(UUID uuid,
                                                              long userId,
                                                              UUID sessionUuid,
                                                              ContextUri rootUri,
                                                              String title,
                                                              String abstractText,
                                                              String summaryText,
                                                              String content) {
        return new ResourceRecordEntity(
                uuid,
                userId,
                ResourceSourceType.CHAT_STAGE_SUMMARY,
                rootUri,
                null,
                Objects.requireNonNull(sessionUuid, "sessionUuid 不能为空"),
                null,
                title,
                abstractText,
                summaryText,
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
     * 更新 L0 摘要文本（~100 token，由 AI 或规则生成）。
     */
    public void updateAbstractText(String abstractText) {
        this.abstractText = abstractText;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 更新 L1 结构化概览（~2k token，由 AI 或规则生成）。
     */
    public void updateSummaryText(String summaryText) {
        this.summaryText = summaryText;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 生成简易 L0 摘要 — 截取标题+正文前 200 字符。
     *
     * <p>用于 Resource 首次保存时的默认 L0 摘要。
     * 后续可由 AI 生成更精确的摘要覆盖。
     */
    public String deriveDefaultAbstract() {
        StringBuilder sb = new StringBuilder();
        if (title != null && !title.isBlank()) {
            sb.append(title);
        }
        if (content != null && !content.isBlank()) {
            if (!sb.isEmpty()) {
                sb.append("：");
            }
            int maxLen = Math.min(content.length(), 200);
            sb.append(content, 0, maxLen);
            if (content.length() > 200) {
                sb.append("…");
            }
        }
        return sb.toString();
    }

    /**
     * 软删除资源。
     */
    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }
}
