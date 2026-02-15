package com.doublez.pocketmindserver.demo;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.model.ToolContext;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.ai.tool.definition.ToolDefinition;
import org.springframework.ai.tool.metadata.ToolMetadata;

import java.util.Map;

class ObservedToolCallbackTest {

    @Test
    void shouldReturnProcessedResultFromContextEngineer() {
        ToolCallback delegate = new ToolCallback() {
            @Override
            public ToolDefinition getToolDefinition() {
                return ToolDefinition.builder()
                        .name("Bash")
                        .inputSchema("{}")
                        .build();
            }

            @Override
            public ToolMetadata getToolMetadata() {
                return ToolMetadata.builder().build();
            }

            @Override
            public String call(String toolInput) {
                return "bash_id: shell_1\nnoise\nExit code: 0\nnoise\n";
            }
        };

        ToolResultContextEngineer contextEngineer = new ToolResultContextEngineer(true, 2, 1000);
        ObservedToolCallback callback = new ObservedToolCallback(delegate, contextEngineer, true, 1000, true);

        String result = callback.call("{}", new ToolContext(Map.of("k", "v")));

        Assertions.assertTrue(result.contains("bash_id: shell_1"));
        Assertions.assertTrue(result.contains("Exit code: 0"));
        Assertions.assertFalse(result.contains("noise\nnoise"));
    }
}
