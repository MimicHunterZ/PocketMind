package com.doublez.pocketmindserver.ai.application.retrieval;

import org.springframework.stereotype.Component;

/**
 * 默认热度评分器 — 精确移植 OpenViking 的 memory_lifecycle.hotness_score。
 *
 * <p>公式：
 * <pre>
 *   freq    = sigmoid(log1p(activeCount))            // 频次组件 → (0, 1)
 *   recency = exp(-ln2 / halfLifeDays × ageDays)     // 衰减组件 → (0, 1]
 *   score   = freq × recency
 * </pre>
 *
 * <p>halfLifeDays = 7.0（与 OpenViking 默认值一致），
 * 含义：7 天前更新的节点热度衰减为一半。
 */
@Component
public class DefaultHotnessScorer implements HotnessScorer {

    /** 衰减半衰期（天），与 OpenViking DEFAULT_HALF_LIFE_DAYS 对齐。 */
    private static final double HALF_LIFE_DAYS = 7.0;

    /** ln(2) / halfLifeDays，预计算避免重复运算。 */
    private static final double DECAY_RATE = Math.log(2) / HALF_LIFE_DAYS;

    /** 一天的毫秒数。 */
    private static final double MILLIS_PER_DAY = 86_400_000.0;

    @Override
    public double score(long activeCount, long updatedAtMillis) {
        return score(activeCount, updatedAtMillis, System.currentTimeMillis());
    }

    @Override
    public double score(long activeCount, long updatedAtMillis, long nowMillis) {
        // 频次组件：sigmoid(log1p(activeCount))
        double freq = 1.0 / (1.0 + Math.exp(-Math.log1p(activeCount)));

        // 时间衰减组件
        if (updatedAtMillis <= 0) {
            return 0.0;
        }
        double ageDays = Math.max((nowMillis - updatedAtMillis) / MILLIS_PER_DAY, 0.0);
        double recency = Math.exp(-DECAY_RATE * ageDays);

        return freq * recency;
    }
}
