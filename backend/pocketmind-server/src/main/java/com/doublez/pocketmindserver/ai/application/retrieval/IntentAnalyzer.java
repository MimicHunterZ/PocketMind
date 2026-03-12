package com.doublez.pocketmindserver.ai.application.retrieval;

/**
 * 意图分析器 — 从用户输入提取检索信号。
 *
 * <p>通过 LLM 分析用户意图，生成类型化检索查询。
 */
public interface IntentAnalyzer {

    /**
     * 分析用户输入，提取检索意图。
     *
     * @param userPrompt 用户原始输入
     * @return 分析结果
     */
    AnalyzedIntent analyze(String userPrompt);
}
