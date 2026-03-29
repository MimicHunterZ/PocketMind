package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * DefaultHierarchicalRetriever 单测（薄索引平铺检索模式）。
 */
class DefaultHierarchicalRetrieverTest {

    private StubSearchStrategy strategy;
    private DefaultHotnessScorer hotnessScorer;
    private DefaultHierarchicalRetriever retriever;

    @BeforeEach
    void setUp() {
        strategy = new StubSearchStrategy();
        hotnessScorer = new DefaultHotnessScorer();
        retriever = new DefaultHierarchicalRetriever(strategy, hotnessScorer);
    }

    @Test
    void 空结果时返回empty() {
        RetrievalQuery query = RetrievalQuery.of("Spring", ContextType.RESOURCE, 5);

        RetrievalResult result = retriever.retrieve(query, 1L);

        assertThat(result.matches()).isEmpty();
        assertThat(result.searchedDirectories()).isEmpty();
    }

    @Test
    void 平铺召回结果会按分数与hotness融合排序() {
        ContextNode highSemantic = node("pm://users/1/resources/a", "A", 0L, 0L);
        ContextNode highHotness = node("pm://users/1/resources/b", "B", 1000L, System.currentTimeMillis());
        strategy.results = List.of(
                new ScoredNode(highSemantic, 0.90),
                new ScoredNode(highHotness, 0.70)
        );

        RetrievalResult result = retriever.retrieve(RetrievalQuery.of("query", ContextType.RESOURCE, 5), 1L);

        assertThat(result.matches()).hasSize(2);
        assertThat(result.searchedDirectories()).hasSize(2);
    }

    @Test
    void 会按limit截断() {
        strategy.results = List.of(
                new ScoredNode(node("pm://users/1/resources/1", "1", 0L, 0L), 0.9),
                new ScoredNode(node("pm://users/1/resources/2", "2", 0L, 0L), 0.8),
                new ScoredNode(node("pm://users/1/resources/3", "3", 0L, 0L), 0.7)
        );

        RetrievalResult result = retriever.retrieve(RetrievalQuery.of("q", ContextType.RESOURCE, 2), 1L);

        assertThat(result.matches()).hasSize(2);
    }

    private ContextNode node(String uri, String name, long activeCount, long updatedAt) {
        ContextUri contextUri = ContextUri.of(uri);
        return new ContextNode(
                contextUri,
                UUID.nameUUIDFromBytes(uri.getBytes()),
                ContextType.RESOURCE,
                name,
                name + " abstract",
                activeCount,
                updatedAt
        );
    }

    private static class StubSearchStrategy implements ChildSearchStrategy {
        private List<ScoredNode> results = List.of();

        @Override
        public List<ScoredNode> search(String queryText, long userId, ContextType contextType, int limit) {
            return results.stream().limit(limit).toList();
        }
    }
}
