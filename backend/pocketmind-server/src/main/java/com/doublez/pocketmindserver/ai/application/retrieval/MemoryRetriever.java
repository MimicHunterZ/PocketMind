package com.doublez.pocketmindserver.ai.application.retrieval;

import java.util.List;

/**
 * 记忆检索器 SPI — 从 memory_records 中检索与查询相关的记忆片段。
 *
 * <p>当前实现：{@link VectorMemoryRetriever} 基于 pgvector 余弦相似度。
 */
public interface MemoryRetriever {

    /**
     * 检索与查询文本相关的记忆片段。
     *
     * @param queryText 自然语言查询
     * @param userId    用户 ID
     * @param limit     返回上限
     * @return 按相关性降序排列的记忆片段
     */
    List<ContextSnippet> retrieve(String queryText, long userId, int limit);
}
