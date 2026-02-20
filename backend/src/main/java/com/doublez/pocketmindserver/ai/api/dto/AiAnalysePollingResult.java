package com.doublez.pocketmindserver.ai.api.dto;

import com.fasterxml.jackson.annotation.JsonPropertyOrder;

import java.util.List;

/**
 * analyse/polling 场景的结构化输出结果。
 */
@JsonPropertyOrder({"summary", "tags", "answer"})
public record AiAnalysePollingResult(
        String summary,
        List<String> tags,
        String answer
) {
}
