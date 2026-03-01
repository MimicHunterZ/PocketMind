package com.doublez.pocketmindserver.ai.context;

import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.jetbrains.annotations.NotNull;
import org.springframework.ai.chat.client.ChatClientRequest;
import org.springframework.ai.chat.client.ChatClientResponse;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.model.tool.ToolCallingManager;
import org.springframework.ai.model.tool.ToolExecutionResult;

import java.util.List;

/**
 * 在剪枝版 ToolCallAdvisor 的基础上，增加 tool_calls/tool_results 落库能力。
 */
public class PersistingPruningToolCallAdvisor extends PruningToolCallAdvisor {

    private final PersistingToolCallAdvisor persister;

    public PersistingPruningToolCallAdvisor(ToolCallingManager toolCallingManager,
                                            double startRatio,
                                            int keepRecentToolResponses,
                                            TrustedModelContextWindowResolver contextWindowResolver,
                                            String modelName,
                                            ChatMessageRepository chatMessageRepository,
                                            ObjectMapper objectMapper) {
        super(toolCallingManager, startRatio, keepRecentToolResponses, contextWindowResolver, modelName);
        this.persister = new PersistingToolCallAdvisor(toolCallingManager, chatMessageRepository, objectMapper);
    }

    @Override
    protected @NotNull List<Message> doGetNextInstructionsForToolCall(@NotNull ChatClientRequest chatClientRequest,
                                                                      @NotNull ChatClientResponse chatClientResponse,
                                                                      ToolExecutionResult toolExecutionResult) {
        List<Message> fullHistory = toolExecutionResult.conversationHistory();
        persister.tryPersistIncremental(fullHistory);
        return super.doGetNextInstructionsForToolCall(chatClientRequest, chatClientResponse, toolExecutionResult);
    }
}
