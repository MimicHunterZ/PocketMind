package com.doublez.pocketmindserver.memory.domain;

/**
 * 记忆证据项 — 标记该记忆来源于哪段上下文。
 *
 * <p>存储在 memory_records.evidence_refs JSONB 列中。
 *
 * @param sourceUri    来源上下文 URI（如 pm://users/1/resources/notes/{uuid}/text）
 * @param snippetRange 原文片段截取范围 / 关键句摘录
 * @param capturedAt   证据捕获时间戳（毫秒）
 */
public record MemoryEvidence(
        String sourceUri,
        String snippetRange,
        long capturedAt
) {

    /**
     * 快速构建证据项。
     */
    public static MemoryEvidence of(String sourceUri, String snippetRange) {
        return new MemoryEvidence(sourceUri, snippetRange, System.currentTimeMillis());
    }
}
