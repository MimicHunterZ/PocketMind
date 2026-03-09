package com.doublez.pocketmindserver.memory.domain;

import com.doublez.pocketmindserver.context.domain.ContextStatus;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.context.domain.SpaceType;
import lombok.EqualsAndHashCode;
import lombok.Getter;

import java.math.BigDecimal;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * 用户长期记忆领域实体 — 对应 memory_records 表。
 *
 * <p>设计要点：
 * <ul>
 *   <li>不可变 ID 与 UUID</li>
 *   <li>L0（abstractText）/ L1（summaryText）/ L2（content）三级信息密度</li>
 *   <li>evidenceRefs 用 JSONB 存储记忆来源证据</li>
 *   <li>mergeKey 用于去重合并</li>
 *   <li>activeCount 跟踪被检索引用的次数（热度）</li>
 * </ul>
 */
@Getter
@EqualsAndHashCode(of = "uuid")
public class MemoryRecordEntity {

    private final UUID uuid;
    private final long userId;
    private Long tenantId;
    private SpaceType spaceType;
    private MemoryType memoryType;
    private ContextUri rootUri;
    private String title;
    private String abstractText;
    private String summaryText;
    private String content;
    private String sourceContextUri;
    private List<MemoryEvidence> evidenceRefs;
    private String mergeKey;
    private BigDecimal confidenceScore;
    private long activeCount;
    private Long lastValidatedAt;
    private ContextStatus status;
    private long updatedAt;
    private boolean deleted;

    public MemoryRecordEntity(UUID uuid,
                              long userId,
                              Long tenantId,
                              SpaceType spaceType,
                              MemoryType memoryType,
                              ContextUri rootUri,
                              String title,
                              String abstractText,
                              String summaryText,
                              String content,
                              String sourceContextUri,
                              List<MemoryEvidence> evidenceRefs,
                              String mergeKey,
                              BigDecimal confidenceScore,
                              long activeCount,
                              Long lastValidatedAt,
                              ContextStatus status,
                              long updatedAt,
                              boolean deleted) {
        this.uuid = Objects.requireNonNull(uuid, "uuid 不能为空");
        this.userId = userId;
        this.tenantId = tenantId;
        this.spaceType = spaceType != null ? spaceType : SpaceType.USER;
        this.memoryType = Objects.requireNonNull(memoryType, "memoryType 不能为空");
        this.rootUri = Objects.requireNonNull(rootUri, "rootUri 不能为空");
        this.title = title;
        this.abstractText = abstractText;
        this.summaryText = summaryText;
        this.content = content;
        this.sourceContextUri = sourceContextUri;
        this.evidenceRefs = evidenceRefs != null ? List.copyOf(evidenceRefs) : List.of();
        this.mergeKey = mergeKey;
        this.confidenceScore = confidenceScore != null ? confidenceScore : BigDecimal.ONE;
        this.activeCount = activeCount;
        this.lastValidatedAt = lastValidatedAt;
        this.status = status != null ? status : ContextStatus.ACTIVE;
        this.updatedAt = updatedAt;
        this.deleted = deleted;
    }

    // ─── 工厂方法 ──────────────────────────────────────────────────

    /**
     * 从 LLM 抽取结果创建新记忆。
     */
    public static MemoryRecordEntity createFromExtraction(
            long userId,
            MemoryType memoryType,
            ContextUri rootUri,
            String title,
            String abstractText,
            String content,
            String sourceContextUri,
            List<MemoryEvidence> evidenceRefs,
            String mergeKey) {
        return new MemoryRecordEntity(
                UUID.randomUUID(),
                userId, null,
                SpaceType.USER,
                memoryType,
                rootUri,
                title,
                abstractText,
                null,
                content,
                sourceContextUri,
                evidenceRefs,
                mergeKey,
                BigDecimal.ONE,
                0L,
                null,
                ContextStatus.ACTIVE,
                System.currentTimeMillis(),
                false
        );
    }

    // ─── 业务方法 ──────────────────────────────────────────────────

    /**
     * 递增引用热度。
     */
    public void incrementActiveCount() {
        this.activeCount++;
    }

    /**
     * 更新内容（合并 / 修正场景）。
     */
    public void updateContent(String title, String abstractText, String content) {
        this.title = title;
        this.abstractText = abstractText;
        this.content = content;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 追加证据来源。
     */
    public void addEvidence(MemoryEvidence evidence) {
        var newList = new java.util.ArrayList<>(this.evidenceRefs);
        newList.add(evidence);
        this.evidenceRefs = List.copyOf(newList);
    }

    /**
     * 标记为已归档。
     */
    public void archive() {
        this.status = ContextStatus.ARCHIVED;
        this.updatedAt = System.currentTimeMillis();
    }

    /**
     * 软删除。
     */
    public void softDelete() {
        this.deleted = true;
        this.updatedAt = System.currentTimeMillis();
    }
}
