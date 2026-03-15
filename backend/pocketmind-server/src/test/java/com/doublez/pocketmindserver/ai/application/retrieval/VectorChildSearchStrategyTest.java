package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.ai.application.embedding.EmbeddingService;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository.ScoredCatalogEntry;
import com.doublez.pocketmindserver.context.domain.ContextLayer;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * VectorChildSearchStrategy 单测 — 使用 Stub 验证向量搜索路由逻辑。
 */
class VectorChildSearchStrategyTest {

    private StubEmbeddingService embeddingService;
    private InMemoryCatalogRepository repository;
    private VectorChildSearchStrategy strategy;

    @BeforeEach
    void setUp() {
        embeddingService = new StubEmbeddingService();
        repository = new InMemoryCatalogRepository();
        strategy = new VectorChildSearchStrategy(embeddingService, repository);
    }

    @Test
    void 向量搜索子节点按相似度返回() {
        long userId = 1L;
        ContextUri root = ContextUri.userResourcesRoot(userId);
        ContextNode high = node(root.child("note-1"), root, "Spring Boot 架构设计", true);
        ContextNode low = node(root.child("note-2"), root, "Rust 入门教程", true);

        repository.addChildVectorResult(root.value(), new ScoredCatalogEntry(high, 0.92));
        repository.addChildVectorResult(root.value(), new ScoredCatalogEntry(low, 0.35));

        List<ScoredNode> results = strategy.searchChildren(root, "Spring 架构", userId, 10);

        assertThat(results).hasSize(2);
        assertThat(results.get(0).node().name()).isEqualTo("Spring Boot 架构设计");
        assertThat(results.get(0).score()).isEqualTo(0.92);
    }

    @Test
    void 全局向量搜索返回匹配结果() {
        long userId = 1L;
        ContextNode hit = node(
                ContextUri.of("pm://users/1/resources/notes/spring"),
                ContextUri.userResourcesRoot(userId),
                "Spring AI 指南", true);

        repository.addGlobalVectorResult(new ScoredCatalogEntry(hit, 0.88));

        List<ScoredNode> results = strategy.globalSearch("Spring AI", userId, ContextType.RESOURCE, 5);

        assertThat(results).hasSize(1);
        assertThat(results.get(0).node().name()).isEqualTo("Spring AI 指南");
        assertThat(results.get(0).score()).isEqualTo(0.88);
    }

    @Test
    void 空白查询返回空列表() {
        embeddingService.setReturnNull(true);

        List<ScoredNode> results = strategy.searchChildren(
                ContextUri.userResourcesRoot(1L), "", 1L, 10);

        assertThat(results).isEmpty();
    }

    @Test
    void loadByUris委托到普通查找() {
        long userId = 1L;
        ContextUri uri = ContextUri.of("pm://users/1/resources/notes/test");
        ContextNode n = node(uri, null, "测试笔记", true);
        repository.addFindByUriResult(uri.value(), n);

        List<ScoredNode> results = strategy.loadByUris(List.of(uri), userId);

        assertThat(results).hasSize(1);
        assertThat(results.get(0).score()).isEqualTo(0.0);
    }

    // ─── 辅助方法 ──────────────────────────────────────────────

    private ContextNode node(ContextUri uri, ContextUri parent, String name, boolean isLeaf) {
        return new ContextNode(uri, parent, ContextType.RESOURCE, ContextLayer.L2_DETAIL,
                name, name + " 的摘要", 0L, System.currentTimeMillis(), isLeaf);
    }

    // ─── Stub EmbeddingService ──────────────────────────────────

    static class StubEmbeddingService extends EmbeddingService {
        private boolean returnNull = false;

        StubEmbeddingService() {
            super(null);
        }

        void setReturnNull(boolean returnNull) {
            this.returnNull = returnNull;
        }

        @Override
        public float[] embed(String text) {
            if (returnNull || text == null || text.isBlank()) {
                return null;
            }
            return new float[]{0.1f, 0.2f, 0.3f};
        }
    }

    // ─── 内存 Repository ─────────────────────────────────────────

    static class InMemoryCatalogRepository implements ContextCatalogRepository {

        private final Map<String, List<ScoredCatalogEntry>> childVectorResults = new ConcurrentHashMap<>();
        private final List<ScoredCatalogEntry> globalVectorResults = new ArrayList<>();
        private final Map<String, ContextNode> uriNodes = new ConcurrentHashMap<>();

        void addChildVectorResult(String parentUri, ScoredCatalogEntry entry) {
            childVectorResults.computeIfAbsent(parentUri, k -> new ArrayList<>()).add(entry);
        }

        void addGlobalVectorResult(ScoredCatalogEntry entry) {
            globalVectorResults.add(entry);
        }

        void addFindByUriResult(String uri, ContextNode node) {
            uriNodes.put(uri, node);
        }

        @Override
        public List<ScoredCatalogEntry> searchByVector(float[] queryVector, long userId, ContextType contextType, int limit) {
            return globalVectorResults.stream().limit(limit).toList();
        }

        @Override
        public List<ScoredCatalogEntry> searchChildrenByVector(float[] queryVector, String parentUri, long userId, int limit) {
            return childVectorResults.getOrDefault(parentUri, List.of()).stream().limit(limit).toList();
        }

        @Override
        public void updateEmbedding(String uri, float[] embedding) {}

        @Override
        public List<ContextNode> findByUris(List<String> uris) {
            return uris.stream()
                    .map(uriNodes::get)
                    .filter(n -> n != null)
                    .toList();
        }

        // ─── 未使用的接口方法 ──────────────────────────────────

        @Override public List<ContextNode> findChildrenByParentUri(String parentUri, long userId) { return List.of(); }
        @Override public List<ContextNode> findDescendantsByUriPrefix(String uriPrefix, long userId) { return List.of(); }
        @Override public List<ContextNode> searchByKeyword(String keyword, Long userId, ContextType contextType, int limit) { return List.of(); }
        @Override public Optional<ContextNode> findByUri(String uri) { return Optional.ofNullable(uriNodes.get(uri)); }
        @Override public void upsert(ContextNode node, Long userId) {}
        @Override public void incrementActiveCount(String uri) {}
        @Override public void incrementActiveCountBatch(List<String> uris) {}
        @Override public void deleteByUri(String uri) {}
    }

}
