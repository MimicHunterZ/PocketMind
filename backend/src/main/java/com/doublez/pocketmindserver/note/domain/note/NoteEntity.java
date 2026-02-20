package com.doublez.pocketmindserver.note.domain.note;

import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.beans.ConstructorProperties;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * 笔记领域实体
 */
@Getter
@EqualsAndHashCode(of = "uuid")
public class NoteEntity {

    private final UUID uuid;
    private final long userId;

    // 用户自己写的内容
    private String title;
    private String content;

    // 来源 URL（对应客户端 note.url）
    private String sourceUrl;

    // 分类（默认 1）
    private long categoryId;

    // 标签（值对象集合，通过 tagId 引用 TagEntity 聚合）
    private final List<NoteTag> tags;

    // 创建时间（对应客户端 note.time）
    private Instant noteTime;

    // 抓取/爬虫结果
    private String previewTitle;
    private String previewDescription;
    private String previewContent;
    private NoteResourceStatus resourceStatus;

    // AI 分析结果（轮询模式）
    private String summary;

    // 预留：持久记忆系统扩展
    private String memoryPath;

    // 同步字段
    private long updatedAt;
    private boolean deleted;

    /**
     * 构造函数仅用于持久化反序列化 / 映射（由 MapStruct 调用）。
     * 业务侧创建请使用 {@link #create(UUID, long)}。
     */
    @ConstructorProperties({
            "uuid",
            "userId",
            "title",
            "content",
            "sourceUrl",
            "categoryId",
            "tags",
            "noteTime",
            "previewTitle",
            "previewDescription",
            "previewContent",
            "resourceStatus",
            "summary",
            "memoryPath",
            "updatedAt",
            "deleted"
    })
    public NoteEntity(UUID uuid,
                      long userId,
                      String title,
                      String content,
                      String sourceUrl,
                      long categoryId,
                      List<NoteTag> tags,
                      Instant noteTime,
                      String previewTitle,
                      String previewDescription,
                      String previewContent,
                      NoteResourceStatus resourceStatus,
                      String summary,
                      String memoryPath,
                      long updatedAt,
                      boolean deleted) {
        this.uuid = Objects.requireNonNull(uuid, "uuid must not be null");
        this.userId = userId;
        this.title = title;
        this.content = content;
        this.sourceUrl = sourceUrl;
        this.categoryId = categoryId > 0 ? categoryId : 1L;
        this.tags = new ArrayList<>(tags != null ? tags : Collections.emptyList());
        this.noteTime = noteTime;
        this.previewTitle = previewTitle;
        this.previewDescription = previewDescription;
        this.previewContent = previewContent;
        this.resourceStatus = resourceStatus != null ? resourceStatus : NoteResourceStatus.NONE;
        this.summary = summary;
        this.memoryPath = memoryPath;
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    // 工厂方法
    /**
     * 创建新笔记。默认资源状态为 NONE（无来源 URL）。
     * 若需绑定 URL，调用 {@link #attachSourceUrl(String)}。
     */
    public static NoteEntity create(UUID uuid, long userId) {
        Objects.requireNonNull(uuid, "uuid must not be null");
        return new NoteEntity(
                uuid,
                userId,
                null,
                null,
                null,
                1L,
                Collections.emptyList(),
                Instant.now(),
                null,
                null,
                null,
                NoteResourceStatus.NONE,
                null,
                null,
                System.currentTimeMillis(),
                false
        );
    }

    /**
     * analyse 受理：清空旧 summary。
     */
    public void clearSummary() {
        this.summary = null;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * analyse 完成：写入 summary。
     */
    public void updateSummary(String summary) {
        this.summary = summary;
        this.updatedAt = System.currentTimeMillis();
    }

    // 业务行为
    /**
     * 更新正文内容
     */
    public void updateContent(String title, String content) {
        this.title = title;
        this.content = content;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 更新分类
     */
    public void changeCategory(long categoryId) {
        if (categoryId <= 0) {
            throw new IllegalArgumentException("categoryId 必须为正数");
        }
        this.categoryId = categoryId;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 修改笔记时间（客户端可编辑）
     */
    public void changeNoteTime(Instant noteTime) {
        this.noteTime = noteTime;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 更新记忆路径（预留字段）
     */
    public void updateMemoryPath(String memoryPath) {
        this.memoryPath = memoryPath;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 同步专用：使用客户端/远端传入的 updatedAt 覆盖本地 updatedAt。
     * LWW 冲突解决基于此时间戳；因此不能强制使用 System.currentTimeMillis()。
     */
    public void overrideUpdatedAtForSync(long updatedAt) {
        this.updatedAt = updatedAt;
    }

    /**
     * 设置来源 URL，并将资源状态置为 PENDING（等待抓取调度）。
     */
    public void attachSourceUrl(String url) {
        this.sourceUrl = url;
        if (url != null && !url.isBlank()) {
            this.resourceStatus = NoteResourceStatus.PENDING;
        }
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 标记"抓取进行中"（由爬虫任务启动时调用）
     */
    public void startFetching() {
        this.resourceStatus = NoteResourceStatus.FETCHING;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 抓取完成：填充预览字段，状态置为 DONE。
     */
    public void completeFetch(String previewTitle, String previewDescription, String previewContent) {
        this.previewTitle = previewTitle;
        this.previewDescription = previewDescription;
        this.previewContent = previewContent;
        this.resourceStatus = NoteResourceStatus.DONE;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 抓取失败。
     */
    public void failFetch() {
        this.resourceStatus = NoteResourceStatus.FAILED;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 将 FAILED 状态重置为 PENDING 以便重试。
     */
    public void resetForRetry() {
        if (this.resourceStatus == NoteResourceStatus.FAILED) {
            this.resourceStatus = NoteResourceStatus.PENDING;
            this.updatedAt = System.currentTimeMillis();
        }
    }

    /**
     * 等待 mq 消费
     */
    public void pendingForFetch() {
        this.resourceStatus = NoteResourceStatus.PENDING;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 设置为 FETCHING
     */
    public void fetching() {
        this.resourceStatus = NoteResourceStatus.FETCHING;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 软删除
     */
    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }

    public List<NoteTag> getTags() {
        return Collections.unmodifiableList(tags);
    }

    // ---- 标签值对象操作 ----

    /**
     * 添加标签关联（幂等：重复 tagId 不添加）
     */
    public void addTag(long tagId) {
        if (tags.stream().noneMatch(t -> t.tagId() == tagId)) {
            tags.add(new NoteTag(tagId));
            this.updatedAt = System.currentTimeMillis();
        }
    }

    /**
     * 移除标签关联
     */
    public void removeTag(long tagId) {
        boolean removed = tags.removeIf(t -> t.tagId() == tagId);
        if (removed) {
            this.updatedAt = System.currentTimeMillis();
        }
    }

    /**
     * 清空所有标签关联
     */
    public void clearTags() {
        if (!tags.isEmpty()) {
            tags.clear();
            this.updatedAt = System.currentTimeMillis();
        }
    }
}
