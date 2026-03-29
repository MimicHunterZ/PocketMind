package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogRuntimeProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executor;
import java.util.concurrent.TimeUnit;

/**
 * 检索编排器 — 并行调度 Resource + Memory 双通道检索，汇总为 {@link OrchestratedContext}。
 *
 * <p>使用 {@link CompletableFuture} 并行执行双通道检索，任一通道失败不影响另一通道。
 */
@Slf4j
@Service
public class RetrievalOrchestrator {

    private static final int RESOURCE_LIMIT = 5;
    private static final int MEMORY_LIMIT = 8;

    private final HierarchicalRetriever hierarchicalRetriever;
    private final MemoryRetriever memoryRetriever;
    private final ResourceRetrievalFallbackService resourceRetrievalFallbackService;
    private final ResourceCatalogRuntimeProperties runtimeProperties;
    private final Executor retrievalExecutor;

    public RetrievalOrchestrator(HierarchicalRetriever hierarchicalRetriever,
                                 MemoryRetriever memoryRetriever,
                                 ResourceRetrievalFallbackService resourceRetrievalFallbackService,
                                 ResourceCatalogRuntimeProperties runtimeProperties) {
        this(hierarchicalRetriever, memoryRetriever, resourceRetrievalFallbackService, runtimeProperties, Runnable::run);
    }

    @Autowired
    public RetrievalOrchestrator(HierarchicalRetriever hierarchicalRetriever,
                                 MemoryRetriever memoryRetriever,
                                 ResourceRetrievalFallbackService resourceRetrievalFallbackService,
                                 ResourceCatalogRuntimeProperties runtimeProperties,
                                 @Qualifier("applicationTaskExecutor")
                                 Executor retrievalExecutor) {
        this.hierarchicalRetriever = hierarchicalRetriever;
        this.memoryRetriever = memoryRetriever;
        this.resourceRetrievalFallbackService = resourceRetrievalFallbackService;
        this.runtimeProperties = runtimeProperties;
        this.retrievalExecutor = retrievalExecutor == null ? Runnable::run : retrievalExecutor;
    }

    /**
     * 并行执行 Resource + Memory 双通道检索。
     *
     * @param userId    用户 ID
     * @param queryText 用户输入文本
     * @return 编排后的检索结果
     */
    public OrchestratedContext retrieve(long userId, String queryText) {
        // 双通道并行检索：任一通道异常不影响另一通道
        CompletableFuture<List<ContextSnippet>> resourceFuture =
                CompletableFuture.supplyAsync(() -> retrieveResources(userId, queryText), retrievalExecutor)
                        .completeOnTimeout(List.of(), 2, TimeUnit.SECONDS)
                        .exceptionally(ex -> {
                            log.warn("[retrieval-orchestrator] resource 通道检索异常: {}", ex.getMessage());
                            return List.of();
                        });

        CompletableFuture<List<ContextSnippet>> memoryFuture =
                CompletableFuture.supplyAsync(() -> retrieveMemories(userId, queryText), retrievalExecutor)
                        .completeOnTimeout(List.of(), 2, TimeUnit.SECONDS)
                        .exceptionally(ex -> {
                            log.warn("[retrieval-orchestrator] memory 通道检索异常: {}", ex.getMessage());
                            return List.of();
                        });

        List<ContextSnippet> resourceSnippets = resourceFuture.join();
        List<ContextSnippet> memorySnippets = memoryFuture.join();

        log.debug("[retrieval-orchestrator] 检索完成: resources={}, memories={}",
                resourceSnippets.size(), memorySnippets.size());

        return new OrchestratedContext(resourceSnippets, memorySnippets);
    }

    // ─── 内部方法 ──────────────────────────────────────────────

    private List<ContextSnippet> retrieveResources(long userId, String queryText) {
        RetrievalQuery query = new RetrievalQuery(queryText, ContextType.RESOURCE, List.of(), RESOURCE_LIMIT);
        RetrievalResult result = hierarchicalRetriever.retrieve(query, userId);

        if (result.matches().isEmpty() && shouldUseFallback()) {
            List<ContextSnippet> fallback = resourceRetrievalFallbackService.search(userId, queryText, RESOURCE_LIMIT);
            if (!fallback.isEmpty()) {
                log.debug("[retrieval-orchestrator] catalog 未命中，触发 resource_records 降级命中: count={}", fallback.size());
            }
            return fallback;
        }

        return result.matches().stream()
            .map(scored -> new ContextSnippet(
                scored.node().uri().value(),
                scored.node().name(),
                scored.node().abstractText(),
                null,
                scored.score(),
                SnippetSource.RESOURCE
            ))
                .toList();
    }

    private List<ContextSnippet> retrieveMemories(long userId, String queryText) {
        return memoryRetriever.retrieve(queryText, userId, MEMORY_LIMIT);
    }

    private boolean shouldUseFallback() {
        if (resourceRetrievalFallbackService == null) {
            return false;
        }
        return runtimeProperties == null || runtimeProperties.isRetrievalFallbackEnabled();
    }
}
