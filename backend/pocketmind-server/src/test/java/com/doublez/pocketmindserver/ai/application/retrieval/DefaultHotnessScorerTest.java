package com.doublez.pocketmindserver.ai.application.retrieval;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * DefaultHotnessScorer 单测 — 对齐 OpenViking test_memory_lifecycle.py。
 */
class DefaultHotnessScorerTest {

    private final DefaultHotnessScorer scorer = new DefaultHotnessScorer();

    @Test
    void 零访问量且无更新时间返回零分() {
        assertThat(scorer.score(0, 0)).isEqualTo(0.0);
    }

    @Test
    void 零访问量但有最近更新时间返回低分() {
        long now = System.currentTimeMillis();
        double score = scorer.score(0, now, now);
        // sigmoid(log1p(0)) = sigmoid(0) = 0.5, recency = 1.0 → 0.5
        assertThat(score).isEqualTo(0.5);
    }

    @Test
    void 高访问量且刚刚更新返回高分() {
        long now = System.currentTimeMillis();
        double score = scorer.score(100, now, now);
        // sigmoid(log1p(100)) ≈ sigmoid(4.615) ≈ 0.990, recency = 1.0 → ~0.990
        assertThat(score).isGreaterThan(0.98);
    }

    @Test
    void 七天前更新热度衰减为一半() {
        long now = System.currentTimeMillis();
        long sevenDaysAgo = now - 7L * 86_400_000L;

        double recent = scorer.score(10, now, now);
        double weekOld = scorer.score(10, sevenDaysAgo, now);

        // halfLife = 7 天，应衰减约 50%
        assertThat(weekOld).isCloseTo(recent * 0.5, org.assertj.core.data.Offset.offset(0.01));
    }

    @Test
    void 未来时间戳不产生负分() {
        long now = System.currentTimeMillis();
        long future = now + 86_400_000L;
        double score = scorer.score(5, future, now);
        // ageDays = max(负值, 0) = 0 → recency = 1.0
        assertThat(score).isGreaterThan(0.0);
    }

    @Test
    void 分数始终在零到一之间() {
        long now = System.currentTimeMillis();
        for (int count : new int[]{0, 1, 10, 100, 1000, 10000}) {
            for (long ageMs : new long[]{0, 86_400_000L, 7 * 86_400_000L, 30 * 86_400_000L}) {
                long updatedAt = ageMs == 0 ? 0 : now - ageMs;
                double score = scorer.score(count, updatedAt, now);
                assertThat(score).isBetween(0.0, 1.0);
            }
        }
    }
}
