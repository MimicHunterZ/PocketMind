package com.doublez.pocketmindserver.context.domain;

import java.util.Objects;

/**
 * 上下文节点 — 层级检索树的最小单元。
 *
 * <p>统一抽象 Resource、Memory、Skill 在层级树中的表示，
 * 同时支持 DB 行 和 文件系统目录/文件 两种物理形态。
 *
 * <ul>
 *   <li>{@link #uri} — 节点唯一标识（pm:// 路径）</li>
 *   <li>{@link #parentUri} — 父节点路径；根节点为 null</li>
 *   <li>{@link #layer} — L0(摘要) / L1(概览) / L2(详情)，决定检索递归深度</li>
 *   <li>{@link #abstractText} — L0 摘要文本，用于快速打分 (~100 token)</li>
 *   <li>{@link #activeCount} — 热度统计，供 Hotness 打分</li>
 *   <li>{@link #isLeaf} — 叶子节点不可再展开</li>
 * </ul>
 *
 * <p>设计约束：此 record 是<b>只读快照</b>，不持有数据库主键，
 * 可安全传递到检索/装配层，不会泄漏持久化细节。
 */
public record ContextNode(
        ContextUri uri,
        ContextUri parentUri,
        ContextType contextType,
        ContextLayer layer,
        String name,
        String abstractText,
        long activeCount,
        long updatedAt,
        boolean isLeaf
) {
    public ContextNode {
        Objects.requireNonNull(uri, "ContextNode.uri 不能为空");
        Objects.requireNonNull(contextType, "ContextNode.contextType 不能为空");
        Objects.requireNonNull(layer, "ContextNode.layer 不能为空");
    }

    /**
     * 是否为目录节点（非叶子），即可继续递归搜索子节点。
     */
    public boolean isDirectory() {
        return !isLeaf;
    }

    /**
     * 是否为 L2 详情节点 — 检索终点，不再深入。
     */
    public boolean isTerminal() {
        return layer == ContextLayer.L2_DETAIL || isLeaf;
    }
}
