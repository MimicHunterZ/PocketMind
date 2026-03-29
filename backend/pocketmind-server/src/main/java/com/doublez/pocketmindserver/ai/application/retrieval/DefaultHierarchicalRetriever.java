package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * 默认检索器（平铺索引模式）。
 *
 * <p>在薄索引架构下，不再依赖 parent_uri/layer 的递归树搜索，
 * 统一采用全局语义召回 + 热度融合排序。
 *
 * <h3>虚拟线程安全</h3>
 * 所有状态均为方法局部变量，无实例可变状态，可安全在虚拟线程中并发调用。
 */
@Slf4j
@Component
public class DefaultHierarchicalRetriever implements HierarchicalRetriever {

    /** 热度融合权重。finalScore = (1 - α) × semanticScore + α × hotnessScore */
    static final double HOTNESS_ALPHA = 0.2;

    private final ChildSearchStrategy childSearchStrategy;
    private final HotnessScorer hotnessScorer;

    public DefaultHierarchicalRetriever(ChildSearchStrategy childSearchStrategy,
                                        HotnessScorer hotnessScorer) {
        this.childSearchStrategy = childSearchStrategy;
        this.hotnessScorer = hotnessScorer;
    }

    @Override
    public RetrievalResult retrieve(RetrievalQuery query, long userId) {
        List<ScoredNode> candidates = childSearchStrategy.search(
                query.queryText(), userId, query.contextType(), query.limit());

        if (candidates.isEmpty()) {
            log.debug("[retrieval] 无起始点, userId={}, query={}", userId, query.queryText());
            return RetrievalResult.empty(query);
        }

        // Hotness 融合与最终排序
        List<ScoredNode> blended = applyHotnessBlending(candidates);

        List<ScoredNode> finalResults = blended.stream()
                .limit(query.limit())
                .toList();

        List<ContextUri> searched = finalResults.stream().map(s -> s.node().uri()).toList();
        return new RetrievalResult(query, finalResults, searched);
    }

    /**
     * Hotness 融合 — 语义分 × (1 - α) + 热度分 × α。
     */
    private List<ScoredNode> applyHotnessBlending(List<ScoredNode> candidates) {
        if (HOTNESS_ALPHA <= 0.0) {
            return candidates;
        }

        return candidates.stream()
                .map(scored -> {
                    ContextNode node = scored.node();
                    double semanticScore = scored.score();
                    double hotness = hotnessScorer.score(node.activeCount(), node.updatedAt());
                    double blended = (1 - HOTNESS_ALPHA) * semanticScore + HOTNESS_ALPHA * hotness;
                    return scored.withScore(blended);
                })
                .sorted(Comparator.comparingDouble(ScoredNode::score).reversed())
                .toList();
    }

}
