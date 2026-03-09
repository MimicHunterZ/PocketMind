package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextUri;

import java.util.List;

/**
 * 层级检索结果。
 *
 * @param query                原始查询
 * @param matches              按 score 降序排列的命中节点
 * @param searchedDirectories  实际搜索过的目录列表（用于调试/审计）
 */
public record RetrievalResult(
        RetrievalQuery query,
        List<ScoredNode> matches,
        List<ContextUri> searchedDirectories
) {
    public RetrievalResult {
        if (matches == null) {
            matches = List.of();
        }
        if (searchedDirectories == null) {
            searchedDirectories = List.of();
        }
    }

    /**
     * 空结果。
     */
    public static RetrievalResult empty(RetrievalQuery query) {
        return new RetrievalResult(query, List.of(), List.of());
    }

    /**
     * 是否有命中结果。
     */
    public boolean hasMatches() {
        return !matches.isEmpty();
    }
}
