package com.doublez.pocketmindserver.ai.application.retrieval;

import java.util.List;

/**
 * 检索编排结果 — 双通道检索的统一输出。
 *
 * @param resourceSnippets Resource 通道命中片段（按 score 降序）
 * @param memorySnippets   Memory 通道命中片段（按 score 降序）
 */
public record OrchestratedContext(
        List<ContextSnippet> resourceSnippets,
        List<ContextSnippet> memorySnippets
) {

    public OrchestratedContext {
        if (resourceSnippets == null) resourceSnippets = List.of();
        if (memorySnippets == null) memorySnippets = List.of();
    }

    public boolean isEmpty() {
        return resourceSnippets.isEmpty() && memorySnippets.isEmpty();
    }

    public static OrchestratedContext empty() {
        return new OrchestratedContext(List.of(), List.of());
    }
}
