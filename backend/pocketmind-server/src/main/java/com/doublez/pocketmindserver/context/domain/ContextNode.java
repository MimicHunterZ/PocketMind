package com.doublez.pocketmindserver.context.domain;

import java.util.Objects;

/**
 * 上下文节点 — 薄索引检索单元。
 *
 * <p>统一抽象 catalog 索引中的最小节点，主要用于检索与排序。
 *
 * <ul>
 *   <li>{@link #uri} — 节点唯一标识（pm:// 路径）</li>
 *   <li>{@link #resourceUuid} — 指向 resource_records 的唯一关联键</li>
 *   <li>{@link #abstractText} — L0 摘要文本，用于快速打分 (~100 token)</li>
 *   <li>{@link #activeCount} — 热度统计，供 Hotness 打分</li>
 * </ul>
 *
 * <p>设计约束：此 record 是<b>只读快照</b>，不持有数据库主键，
 * 可安全传递到检索/装配层，不会泄漏持久化细节。
 */
public record ContextNode(
        ContextUri uri,
        java.util.UUID resourceUuid,
        ContextType contextType,
        String name,
        String abstractText,
        long activeCount,
        long updatedAt
) {
    public ContextNode {
        Objects.requireNonNull(uri, "ContextNode.uri 不能为空");
        Objects.requireNonNull(resourceUuid, "ContextNode.resourceUuid 不能为空");
        Objects.requireNonNull(contextType, "ContextNode.contextType 不能为空");
    }
}
