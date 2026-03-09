package com.doublez.pocketmindserver.ai.application.retrieval;

/**
 * 热度评分器 — 基于访问频次与时间衰减计算 0.0–1.0 热度分。
 *
 * <p>对齐 OpenViking {@code memory_lifecycle.hotness_score}，
 * 公式：{@code sigmoid(log1p(activeCount)) × exp(-decay × ageDays)}
 *
 * <p>热度分与语义分融合公式：
 * {@code finalScore = (1 - α) × semanticScore + α × hotnessScore}
 * 其中 α = {@link DefaultHierarchicalRetriever#HOTNESS_ALPHA}。
 */
public interface HotnessScorer {

    /**
     * 计算热度分。
     *
     * @param activeCount    累计访问次数
     * @param updatedAtMillis 最后更新时间戳（毫秒），0 表示未知
     * @return 热度分 [0.0, 1.0]
     */
    double score(long activeCount, long updatedAtMillis);

    /**
     * 计算热度分（指定当前时间，用于确定性测试）。
     *
     * @param activeCount     累计访问次数
     * @param updatedAtMillis 最后更新时间戳（毫秒），0 表示未知
     * @param nowMillis       当前时间戳（毫秒）
     * @return 热度分 [0.0, 1.0]
     */
    double score(long activeCount, long updatedAtMillis, long nowMillis);
}
