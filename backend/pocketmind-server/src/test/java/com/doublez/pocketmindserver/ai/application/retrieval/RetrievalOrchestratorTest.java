package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextLayer;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * RetrievalOrchestrator 单元测试 — 验证双通道并行编排。
 */
class RetrievalOrchestratorTest {

    private StubHierarchicalRetriever resourceRetriever;
    private StubMemoryRetriever memoryRetriever;
    private RetrievalOrchestrator orchestrator;

    @BeforeEach
    void setUp() {
        resourceRetriever = new StubHierarchicalRetriever();
        memoryRetriever = new StubMemoryRetriever();
        orchestrator = new RetrievalOrchestrator(resourceRetriever, memoryRetriever);
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

    // ─── 辅助方法 ──────────────────────────────────────────────

    private ScoredNode scoredNode(String name, double score) {
        ContextUri uri = ContextUri.of("pm://users/1/resources/" + name.hashCode());
        ContextNode node = new ContextNode(
                uri, null, ContextType.RESOURCE, ContextLayer.L1_OVERVIEW,
                name, name + " 的摘要", 0L, 0L, true);
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
}
