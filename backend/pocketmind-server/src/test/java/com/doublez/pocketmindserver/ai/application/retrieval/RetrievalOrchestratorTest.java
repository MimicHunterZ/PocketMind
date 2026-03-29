package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogRuntimeProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * RetrievalOrchestrator 单元测试 — 验证双通道并行编排。
 */
class RetrievalOrchestratorTest {

    private StubHierarchicalRetriever resourceRetriever;
    private StubMemoryRetriever memoryRetriever;
    private StubResourceFallbackService fallbackService;
    private RetrievalOrchestrator orchestrator;

    @BeforeEach
    void setUp() {
        resourceRetriever = new StubHierarchicalRetriever();
        memoryRetriever = new StubMemoryRetriever();
        fallbackService = new StubResourceFallbackService();
        orchestrator = new RetrievalOrchestrator(
                resourceRetriever,
                memoryRetriever,
                fallbackService,
                new ResourceCatalogRuntimeProperties(true, 100, 5000L, true)
        );
    }

    @Test
    void 双通道均有结果时正确合并() {
        resourceRetriever.setResults(List.of(
                scoredNode("Spring 架构笔记", 0.9),
                scoredNode("Flutter 入门", 0.5)
        ));
        memoryRetriever.setResults(List.of(
                memorySnippet("用户偏好深色模式", 0.8),
                memorySnippet("用户是Java工程师", 0.7)
        ));

        OrchestratedContext ctx = orchestrator.retrieve(1L, "Spring 开发");

        assertThat(ctx.resourceSnippets()).hasSize(2);
        assertThat(ctx.memorySnippets()).hasSize(2);
        assertThat(ctx.isEmpty()).isFalse();
    }

    @Test
    void 资源通道为空时仅返回记忆() {
        resourceRetriever.setResults(List.of());
        fallbackService.setResults(List.of());
        memoryRetriever.setResults(List.of(
                memorySnippet("用户年龄30岁", 0.9)
        ));

        OrchestratedContext ctx = orchestrator.retrieve(1L, "用户信息");

        assertThat(ctx.resourceSnippets()).isEmpty();
        assertThat(ctx.memorySnippets()).hasSize(1);
        assertThat(ctx.isEmpty()).isFalse();
    }

    @Test
    void 双通道均为空时返回空结果() {
        resourceRetriever.setResults(List.of());
        fallbackService.setResults(List.of());
        memoryRetriever.setResults(List.of());

        OrchestratedContext ctx = orchestrator.retrieve(1L, "无关查询");

        assertThat(ctx.isEmpty()).isTrue();
    }

    @Test
    void 资源通道异常时记忆通道不受影响() {
        resourceRetriever.setException(new RuntimeException("DB 连接超时"));
        memoryRetriever.setResults(List.of(
                memorySnippet("Java 偏好", 0.8)
        ));

        OrchestratedContext ctx = orchestrator.retrieve(1L, "Java");

        // 资源通道降级为空，记忆通道正常返回
        assertThat(ctx.resourceSnippets()).isEmpty();
        assertThat(ctx.memorySnippets()).hasSize(1);
    }

    @Test
    void 记忆通道异常时资源通道不受影响() {
        memoryRetriever.setException(new RuntimeException("记忆服务异常"));
        resourceRetriever.setResults(List.of(
                scoredNode("架构文档", 0.9)
        ));

        OrchestratedContext ctx = orchestrator.retrieve(1L, "架构");

        assertThat(ctx.memorySnippets()).isEmpty();
        assertThat(ctx.resourceSnippets()).hasSize(1);
    }

    @Test
    void catalog未命中时使用resource降级检索() {
        resourceRetriever.setResults(List.of());
        memoryRetriever.setResults(List.of());
        fallbackService.setResults(List.of(
                new ContextSnippet(
                        "pm://users/1/resources/fallback-1",
                        "降级资源",
                        "来自 resource_records 降级",
                        null,
                        0.45,
                        SnippetSource.RESOURCE
                )
        ));

        OrchestratedContext ctx = orchestrator.retrieve(1L, "降级查询");

        assertThat(ctx.resourceSnippets()).hasSize(1);
        assertThat(ctx.resourceSnippets().getFirst().title()).isEqualTo("降级资源");
    }

    @Test
    void catalog未命中且fallback关闭时不走降级检索() {
        resourceRetriever.setResults(List.of());
        memoryRetriever.setResults(List.of());
        fallbackService.setResults(List.of(
                new ContextSnippet(
                        "pm://users/1/resources/fallback-2",
                        "不应该返回的降级资源",
                        "fallback 关闭时不应命中",
                        null,
                        0.45,
                        SnippetSource.RESOURCE
                )
        ));
        RetrievalOrchestrator orchestratorWithFallbackDisabled = new RetrievalOrchestrator(
                resourceRetriever,
                memoryRetriever,
                fallbackService,
                new ResourceCatalogRuntimeProperties(false, 100, 5000L, true)
        );

        OrchestratedContext ctx = orchestratorWithFallbackDisabled.retrieve(1L, "降级查询");

        assertThat(ctx.resourceSnippets()).isEmpty();
        assertThat(ctx.isEmpty()).isTrue();
    }

    // ─── 辅助方法 ──────────────────────────────────────────────

    private ScoredNode scoredNode(String name, double score) {
        ContextUri uri = ContextUri.of("pm://users/1/resources/" + name.hashCode());
        ContextNode node = new ContextNode(
                uri,
                UUID.nameUUIDFromBytes(uri.value().getBytes()),
                ContextType.RESOURCE,
                name,
                name + " 的摘要",
                0L,
                0L);
        return new ScoredNode(node, score);
    }

    private ContextSnippet memorySnippet(String title, double score) {
        return new ContextSnippet(
                "pm://users/1/memories/" + title.hashCode(),
                title,
                title + " 的摘要",
                title + " 的详细内容",
                score,
                SnippetSource.MEMORY
        );
    }

    // ─── Stub 实现 ──────────────────────────────────────────────

    static class StubHierarchicalRetriever implements HierarchicalRetriever {
        private List<ScoredNode> results = List.of();
        private RuntimeException exception;

        void setResults(List<ScoredNode> results) { this.results = results; }
        void setException(RuntimeException exception) { this.exception = exception; }

        @Override
        public RetrievalResult retrieve(RetrievalQuery query, long userId) {
            if (exception != null) throw exception;
            return new RetrievalResult(query, results, List.of());
        }
    }

    static class StubMemoryRetriever implements MemoryRetriever {
        private List<ContextSnippet> results = List.of();
        private RuntimeException exception;

        void setResults(List<ContextSnippet> results) { this.results = results; }
        void setException(RuntimeException exception) { this.exception = exception; }

        @Override
        public List<ContextSnippet> retrieve(String queryText, long userId, int limit) {
            if (exception != null) throw exception;
            return results.stream().limit(limit).toList();
        }
    }

    static class StubResourceFallbackService extends ResourceRetrievalFallbackService {
        private List<ContextSnippet> results = List.of();

        StubResourceFallbackService() {
            super(new com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository() {
                @Override public void save(com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity resourceRecord) {}
                @Override public void update(com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity resourceRecord) {}
                @Override public java.util.Optional<com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity> findByUuidAndUserId(java.util.UUID uuid, long userId) { return java.util.Optional.empty(); }
                @Override public java.util.Optional<com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity> findByRootUriAndUserId(String rootUri, long userId) { return java.util.Optional.empty(); }
                @Override public java.util.List<com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity> findByNoteUuid(long userId, java.util.UUID noteUuid) { return java.util.List.of(); }
                @Override public java.util.List<com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity> findBySessionUuid(long userId, java.util.UUID sessionUuid) { return java.util.List.of(); }
                @Override public java.util.List<com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity> findByAssetUuid(long userId, java.util.UUID assetUuid) { return java.util.List.of(); }
                @Override public java.util.List<com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity> searchByKeyword(long userId, String keyword, int limit) { return java.util.List.of(); }
            });
        }

        void setResults(List<ContextSnippet> results) { this.results = results; }

        @Override
        public List<ContextSnippet> search(long userId, String queryText, int limit) {
            return results.stream().limit(limit).toList();
        }
    }
}
