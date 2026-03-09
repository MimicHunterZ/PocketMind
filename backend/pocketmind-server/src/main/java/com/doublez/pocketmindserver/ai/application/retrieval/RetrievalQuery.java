package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;

import java.util.List;

/**
 * 层级检索查询规格。
 *
 * <p>对齐 OpenViking 的 {@code TypedQuery}，但去掉了文件系统相关字段。
 *
 * @param queryText          自然语言查询文本
 * @param contextType        限定搜索类型（null = 搜索所有类型）
 * @param targetDirectories  显式指定搜索起始目录（空列表 = 按 contextType 自动推导根节点）
 * @param limit              返回结果上限
 */
public record RetrievalQuery(
        String queryText,
        ContextType contextType,
        List<ContextUri> targetDirectories,
        int limit
) {
    public RetrievalQuery {
        if (queryText == null || queryText.isBlank()) {
            throw new IllegalArgumentException("queryText 不能为空");
        }
        if (limit <= 0) {
            throw new IllegalArgumentException("limit 必须大于 0");
        }
        if (targetDirectories == null) {
            targetDirectories = List.of();
        }
    }

    /**
     * 快捷构造：仅指定查询文本和上限。
     */
    public static RetrievalQuery of(String queryText, int limit) {
        return new RetrievalQuery(queryText, null, List.of(), limit);
    }

    /**
     * 快捷构造：指定查询文本、类型和上限。
     */
    public static RetrievalQuery of(String queryText, ContextType contextType, int limit) {
        return new RetrievalQuery(queryText, contextType, List.of(), limit);
    }
}
