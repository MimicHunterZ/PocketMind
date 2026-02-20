package com.doublez.pocketmindserver.ai.context;

import com.doublez.pocketmindserver.chat.application.ChatPersistenceContext;
import com.doublez.pocketmindserver.chat.application.ChatPersistenceContextHolder;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.jetbrains.annotations.NotNull;
import org.slf4j.MDC;
import org.springframework.ai.chat.client.ChatClientRequest;
import org.springframework.ai.chat.client.ChatClientResponse;
import org.springframework.ai.chat.client.advisor.ToolCallAdvisor;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.MessageType;
import org.springframework.ai.chat.messages.ToolResponseMessage;
import org.springframework.ai.model.tool.ToolCallingManager;
import org.springframework.ai.model.tool.ToolExecutionResult;
import org.springframework.core.Ordered;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/**
 * ToolCallAdvisor 的持久化增强：将 tool_calls/tool_results 写入 chat_messages。
 * 仅在 ChatPersistenceContextHolder 存在时生效。
 */
@Slf4j
public class PersistingToolCallAdvisor extends ToolCallAdvisor {

    private final ChatMessageRepository chatMessageRepository;
    private final ObjectMapper objectMapper;

    /**
     * 基于 traceId 记录已持久化的 history 长度，防止重复写入。
     */
    private final ConcurrentMap<String, Integer> persistedSizes = new ConcurrentHashMap<>();
    private static final int MAX_TRACKED_CONVERSATIONS = 200;

    public PersistingToolCallAdvisor(ToolCallingManager toolCallingManager,
                                     ChatMessageRepository chatMessageRepository,
                                     ObjectMapper objectMapper) {
        super(toolCallingManager, Ordered.HIGHEST_PRECEDENCE + 300);
        this.chatMessageRepository = chatMessageRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    protected @NotNull List<Message> doGetNextInstructionsForToolCall(@NotNull ChatClientRequest chatClientRequest,
                                                                      @NotNull ChatClientResponse chatClientResponse,
                                                                      ToolExecutionResult toolExecutionResult) {
        List<Message> fullHistory = toolExecutionResult.conversationHistory();
        tryPersistIncremental(fullHistory);
        return super.doGetNextInstructionsForToolCall(chatClientRequest, chatClientResponse, toolExecutionResult);
    }

    protected void tryPersistIncremental(List<Message> fullHistory) {
        ChatPersistenceContext ctx = ChatPersistenceContextHolder.get();
        if (ctx == null) {
            return;
        }
        if (fullHistory == null || fullHistory.isEmpty()) {
            return;
        }

        String traceId = MDC.get("traceId");
        String key = (traceId == null || traceId.isBlank())
                ? (ctx.sessionUuid() == null ? "" : ctx.sessionUuid().toString())
                : traceId;

        int lastSize = persistedSizes.getOrDefault(key, 0);
        if (lastSize >= fullHistory.size()) {
            return;
        }

        // 仅持久化新增片段
        List<Message> delta = fullHistory.subList(lastSize, fullHistory.size());
        persistMessages(ctx, delta);
        persistedSizes.put(key, fullHistory.size());
        evictWhenTooManyConversations();
    }

    private void evictWhenTooManyConversations() {
        if (persistedSizes.size() <= MAX_TRACKED_CONVERSATIONS) {
            return;
        }
        // 简单淘汰：移除一个任意 key
        String anyKey = persistedSizes.keySet().stream().findFirst().orElse(null);
        if (anyKey != null) {
            persistedSizes.remove(anyKey);
        }
    }

    private void persistMessages(ChatPersistenceContext ctx, List<Message> messages) {
        UUID parentUuid = ChatPersistenceContextHolder.getParentUuid();
        if (parentUuid == null) {
            parentUuid = ctx.parentUuid();
        }

        for (Message message : messages) {
            if (message == null) {
                continue;
            }

            if (message.getMessageType() == MessageType.ASSISTANT && message instanceof AssistantMessage assistant) {
                if (assistant.getToolCalls() == null || assistant.getToolCalls().isEmpty()) {
                    continue;
                }
                for (AssistantMessage.ToolCall call : assistant.getToolCalls()) {
                    UUID uuid = UUID.randomUUID();
                    String json = toToolCallJson(call);
                    ChatMessageEntity entity = ChatMessageEntity.createTool(
                            uuid,
                            ctx.userId(),
                            ctx.sessionUuid(),
                            parentUuid,
                            "TOOL_CALL",
                            ChatRole.TOOL_CALL,
                            json
                    );
                    chatMessageRepository.save(entity);
                    parentUuid = uuid;
                    ChatPersistenceContextHolder.updateParentUuid(uuid);
                }
                continue;
            }

            if (message.getMessageType() == MessageType.TOOL && message instanceof ToolResponseMessage toolResponseMessage) {
                for (ToolResponseMessage.ToolResponse resp : toolResponseMessage.getResponses()) {
                    UUID uuid = UUID.randomUUID();
                    String json = toToolResultJson(resp);
                    ChatMessageEntity entity = ChatMessageEntity.createTool(
                            uuid,
                            ctx.userId(),
                            ctx.sessionUuid(),
                            parentUuid,
                            "TOOL_RESULT",
                            ChatRole.TOOL_RESULT,
                            json
                    );
                    chatMessageRepository.save(entity);
                    parentUuid = uuid;
                    ChatPersistenceContextHolder.updateParentUuid(uuid);
                }
            }
        }
    }

    private String toToolCallJson(AssistantMessage.ToolCall call) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("toolCallId", call.id());
        map.put("type", call.type());
        map.put("name", call.name());
        map.put("arguments", call.arguments());
        return writeJson(map);
    }

    private String toToolResultJson(ToolResponseMessage.ToolResponse resp) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("toolCallId", resp.id());
        map.put("name", resp.name());
        map.put("result", resp.responseData());
        return writeJson(map);
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception e) {
            log.warn("tool payload json serialize failed: {}", e.getMessage());
            return "{}";
        }
    }
}
