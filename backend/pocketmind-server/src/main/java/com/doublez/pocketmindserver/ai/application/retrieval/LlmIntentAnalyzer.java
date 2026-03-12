package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

/**
 * LLM 意图分析器 — 通过大模型分析用户输入并生成类型化检索查询。
 */
@Slf4j
@Component
public class LlmIntentAnalyzer implements IntentAnalyzer {

    private static final int MAX_INPUT_LENGTH = 500;

    private final AiFailoverRouter aiFailoverRouter;
    private final ObjectMapper objectMapper;

    @Value("classpath:prompts/retrieval/intent_analysis_system.md")
    private Resource systemTemplate;

    @Value("classpath:prompts/retrieval/intent_analysis_user.md")
    private Resource userTemplate;

    public LlmIntentAnalyzer(AiFailoverRouter aiFailoverRouter, ObjectMapper objectMapper) {
        this.aiFailoverRouter = aiFailoverRouter;
        this.objectMapper = objectMapper;
    }

    @Override
    public AnalyzedIntent analyze(String userPrompt) {
        if (userPrompt == null || userPrompt.isBlank()) {
            return AnalyzedIntent.skip("空输入");
        }

        String trimmed = userPrompt.strip();
        if (trimmed.length() > MAX_INPUT_LENGTH) {
            trimmed = trimmed.substring(0, MAX_INPUT_LENGTH);
        }

        try {
            Prompt prompt = PromptBuilder.build(
                    systemTemplate,
                    userTemplate,
                    Map.of("currentMessage", trimmed)
            );

            String response = aiFailoverRouter.executeChat(
                    "intent-analysis",
                    client -> client.prompt(prompt).call().content()
            );

            return parseResponse(response);
        } catch (Exception e) {
            log.warn("[intent-analyzer] LLM 意图分析失败，降级为透传: {}", e.getMessage());
            return AnalyzedIntent.passthrough(trimmed);
        }
    }

    /**
     * 解析 LLM 返回的 JSON 为 AnalyzedIntent。
     */
    private AnalyzedIntent parseResponse(String response) {
        try {
            String json = extractJson(response);
            Map<String, Object> parsed = objectMapper.readValue(json, new TypeReference<>() {});

            String reasoning = (String) parsed.getOrDefault("reasoning", "");
            List<?> rawQueries = (List<?>) parsed.getOrDefault("queries", List.of());

            List<TypedQuery> queries = rawQueries.stream()
                    .map(item -> {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> q = (Map<String, Object>) item;
                        return new TypedQuery(
                                (String) q.getOrDefault("query", ""),
                                (String) q.getOrDefault("context_type", "resource"),
                                (String) q.getOrDefault("intent", ""),
                                q.containsKey("priority") ? ((Number) q.get("priority")).intValue() : 3
                        );
                    })
                    .sorted()
                    .toList();

            boolean needsRetrieval = !queries.isEmpty();
            log.debug("[intent-analyzer] 分析完成: queries={}, needsRetrieval={}", queries.size(), needsRetrieval);
            return new AnalyzedIntent(reasoning, queries, needsRetrieval);
        } catch (Exception e) {
            log.warn("[intent-analyzer] JSON 解析失败: {}", e.getMessage());
            return AnalyzedIntent.passthrough(response);
        }
    }

    /**
     * 从 LLM 响应中提取 JSON 内容（处理可能的 Markdown 代码块包裹）。
     */
    private String extractJson(String response) {
        if (response == null || response.isBlank()) {
            return "{}";
        }
        String trimmed = response.strip();
        // 处理 ```json ... ``` 包裹
        if (trimmed.startsWith("```")) {
            int firstNewline = trimmed.indexOf('\n');
            int lastFence = trimmed.lastIndexOf("```");
            if (firstNewline > 0 && lastFence > firstNewline) {
                trimmed = trimmed.substring(firstNewline + 1, lastFence).strip();
            }
        }
        return trimmed;
    }
}
