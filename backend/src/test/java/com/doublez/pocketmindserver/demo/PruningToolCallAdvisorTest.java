package com.doublez.pocketmindserver.demo;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.SystemMessage;
import org.springframework.ai.chat.messages.ToolResponseMessage;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.model.tool.ToolExecutionResult;
import org.springframework.ai.model.tool.ToolCallingManager;

import java.util.List;
import java.util.Map;

class PruningToolCallAdvisorTest {

    @Test
    void shouldKeepOnlyRecentToolResponsesWhenRatioHigh() {
        TrustedModelContextWindowResolver resolver = new TrustedModelContextWindowResolver(
                10,
                Map.of("deepseek-chat", 10)
        );

        PruningToolCallAdvisor advisor = new PruningToolCallAdvisor(
                ToolCallingManager.builder().build(),
                0.75,
                1,
                resolver,
                "deepseek-chat"
        );

        // 这里用 AssistantMessage + ToolResponseMessage 的排列，模拟真实 tool loop 的结构：
        // assistant(tool_calls) -> TOOL responses...
        AssistantMessage assistantToolCall1 = new AssistantMessage("call tool round-1");
        AssistantMessage assistantToolCall2 = new AssistantMessage("call tool round-2");

        ToolResponseMessage tool1 = ToolResponseMessage.builder().responses(List.of(
                new ToolResponseMessage.ToolResponse("1", "Bash", "x".repeat(500))
        )).build();
        ToolResponseMessage tool2 = ToolResponseMessage.builder().responses(List.of(
                new ToolResponseMessage.ToolResponse("2", "Bash", "y".repeat(500))
        )).build();
        ToolResponseMessage tool3 = ToolResponseMessage.builder().responses(List.of(
                new ToolResponseMessage.ToolResponse("3", "Bash", "z".repeat(500))
        )).build();

        List<Message> history = List.of(
                new SystemMessage("sys"),
                new UserMessage("user"),
                assistantToolCall1,
                tool1,
                assistantToolCall2,
                tool2,
                tool3
        );

        ToolExecutionResult toolExecutionResult = () -> history;

        List<org.springframework.ai.chat.messages.Message> next = advisor.doGetNextInstructionsForToolCall(
                null,
                null,
                toolExecutionResult
        );

                // keepRecentToolResponses=1：应只保留最后一个「tool-call 块」（assistantToolCall2 + tool2 + tool3）。
                Assertions.assertFalse(next.contains(assistantToolCall1));
                Assertions.assertFalse(next.contains(tool1));

                Assertions.assertTrue(next.contains(assistantToolCall2));
                Assertions.assertTrue(next.contains(tool2));
                Assertions.assertTrue(next.contains(tool3));

                long toolCount = next.stream().filter(m -> m instanceof ToolResponseMessage).count();
                Assertions.assertEquals(2, toolCount);
        Assertions.assertTrue(next.stream().anyMatch(m -> m instanceof SystemMessage));
        Assertions.assertTrue(next.stream().anyMatch(m -> m instanceof UserMessage));
    }
}
