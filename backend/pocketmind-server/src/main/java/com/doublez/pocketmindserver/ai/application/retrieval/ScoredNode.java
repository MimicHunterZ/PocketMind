package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextNode;

/**
 * 带得分的上下文节点。
 *
 * <p>在层级检索过程中，每个候选节点都附带一个 0.0–1.0 范围内的综合得分。
 * 得分由两部分融合：
 * <ul>
 *   <li><b>语义得分</b> — 关键词匹配 / 向量相似度（由 {@link ChildSearchStrategy} 提供）</li>
 *   <li><b>热度得分</b> — 基于 activeCount + 时间衰减（由 {@link HotnessScorer} 计算）</li>
 * </ul>
 *
 * @param node  上下文节点
 * @param score 综合得分（0.0–1.0，分数越高越相关）
 */
public record ScoredNode(ContextNode node, double score) implements Comparable<ScoredNode> {

    /**
     * 按分数降序排列（高分优先）。
     */
    @Override
    public int compareTo(ScoredNode other) {
        return Double.compare(other.score, this.score);
    }

    /**
     * 用新的分数创建副本（score propagation 时使用）。
     */
    public ScoredNode withScore(double newScore) {
        return new ScoredNode(node, newScore);
    }
}
