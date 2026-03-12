package com.doublez.pocketmindserver.ai.application.retrieval;

import java.util.List;

/**
 * 意图分析结果 — LLM 从用户输入中提取的类型化检索查询。
 *
 * @param reasoning      LLM 分析推理过程
 * @param queries        类型化检索查询列表（按优先级排序）
 * @param needsRetrieval 是否需要执行资源检索（对话型任务可跳过）
 */
public record AnalyzedIntent(
        String reasoning,
        List<TypedQuery> queries,
        boolean needsRetrieval
) {
    /**
     * 直通构造：原样透传用户输入，生成默认 resource 查询。
     */
    public static AnalyzedIntent passthrough(String userPrompt) {
        return new AnalyzedIntent(
                "透传：直接使用原始输入作为资源检索查询",
                List.of(new TypedQuery(userPrompt, "resource", "默认资源检索", 1)),
                true
        );
    }

    /**
     * 跳过检索（对话型任务）。
     */
    public static AnalyzedIntent skip(String reasoning) {
        return new AnalyzedIntent(reasoning, List.of(), false);
    }

    /**
     * 获取最高优先级的检索文本（兼容旧调用方）。
     */
    public String queryText() {
        if (queries == null || queries.isEmpty()) return "";
        return queries.getFirst().query();
    }
}
