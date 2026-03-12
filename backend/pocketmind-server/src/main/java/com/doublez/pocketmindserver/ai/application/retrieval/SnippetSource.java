package com.doublez.pocketmindserver.ai.application.retrieval;

/**
 * 检索结果片段来源通道。
 */
public enum SnippetSource {
    /** 来自 Resource 检索（context_catalog 层级搜索） */
    RESOURCE,
    /** 来自 Memory 检索（memory_records 关键词/向量搜索） */
    MEMORY
}
