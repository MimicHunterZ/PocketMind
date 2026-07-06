package com.doublez.pocketmindserver.ai.context;

import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClientRequest;
import org.springframework.ai.chat.client.ChatClientResponse;
import org.springframework.ai.chat.client.advisor.api.CallAdvisor;
import org.springframework.ai.chat.client.advisor.api.CallAdvisorChain;
import org.springframework.ai.chat.client.advisor.api.StreamAdvisor;
import org.springframework.ai.chat.client.advisor.api.StreamAdvisorChain;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.MessageType;
import org.springframework.ai.chat.messages.ToolResponseMessage;
import org.springframework.core.Ordered;
import reactor.core.publisher.Flux;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/**
 * 观察工具调用循环的每一轮请求，把新增的 tool_call/tool_result 落库为 chat_messages。
 *
 * 挂在自动注册的 ToolCallingAdvisor（order = HIGHEST_PRECEDENCE + 300）之后，是 Spring AI 2.0
 * 官方推荐的"循环内观察者"写法：同一个 advisor 同时实现 CallAdvisor/StreamAdvisor，天然覆盖
 * .call() 和 .stream() 两条路径。旧实现继承 ToolCallAdvisor 覆写
 * doGetNextInstructionsForToolCall，那个钩子只在阻塞调用路径触发，流式路径永远走不到。
 *
 * 调用方必须通过 .advisors(a -> a.param(...)) 挂载 CTX_CONVERSATION_KEY/CTX_USER_ID/CTX_SESSION_UUID，
 * 否则视为无需落库的场景（比如没有会话上下文的一次性调用），直接放行不做任何事。
 * 用请求级 context map 而不是 ThreadLocal，是因为 .stream() 的回调可能跑在别的线程上，
 * ThreadLocal 过不去；context map 随 ChatClientRequest 本身流转，没有这个问题。
 */
@Slf4j
public class PersistingToolCallAdvisor implements CallAdvisor, StreamAdvisor {

    public static final String CTX_CONVERSATION_KEY = "pm.persist.conversationKey";
    public static final String CTX_USER_ID = "pm.persist.userId";
    public static final String CTX_SESSION_UUID = "pm.persist.sessionUuid";
    public static final String CTX_PARENT_UUID = "pm.persist.parentUuid";

    private static final int MAX_TRACKED_CONVERSATIONS = 200;

    private final ChatMessageRepository chatMessageRepository;
    private final ObjectMapper objectMapper;

    /**
     * conversationKey -> 已落库的 instructions 长度 / 落库链尾 uuid。
     */
    private final ConcurrentMap<String, Integer> persistedSizes = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, UUID> tailParentUuids = new ConcurrentHashMap<>();

    public PersistingToolCallAdvisor(ChatMessageRepository chatMessageRepository, ObjectMapper objectMapper) {
        this.chatMessageRepository = chatMessageRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    public String getName() {
        return "PersistingToolCallAdvisor";
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE + 400;
    }

    @Override
    public ChatClientResponse adviseCall(ChatClientRequest chatClientRequest, CallAdvisorChain chain) {
        persistNewMessages(chatClientRequest);
        return chain.nextCall(chatClientRequest);
    }

    @Override
    public Flux<ChatClientResponse> adviseStream(ChatClientRequest chatClientRequest, StreamAdvisorChain chain) {
        persistNewMessages(chatClientRequest);
        return chain.nextStream(chatClientRequest);
    }

    private void persistNewMessages(ChatClientRequest chatClientRequest) {
        Map<String, Object> ctx = chatClientRequest.context();
        String conversationKey = (String) ctx.get(CTX_CONVERSATION_KEY);
        Object rawUserId = ctx.get(CTX_USER_ID);
        Object rawSessionUuid = ctx.get(CTX_SESSION_UUID);
        if (conversationKey == null || rawUserId == null || rawSessionUuid == null) {
            return;
        }
        long userId = (Long) rawUserId;
        UUID sessionUuid = (UUID) rawSessionUuid;

        List<Message> instructions = chatClientRequest.prompt().getInstructions();
        int lastSize = persistedSizes.getOrDefault(conversationKey, 0);
        if (instructions.size() <= lastSize) {
            return;
        }

        UUID parentUuid = tailParentUuids.get(conversationKey);
        if (parentUuid == null) {
            parentUuid = (UUID) ctx.get(CTX_PARENT_UUID);
        }

        List<Message> delta = instructions.subList(lastSize, instructions.size());
        parentUuid = persistMessages(userId, sessionUuid, parentUuid, delta);

        persistedSizes.put(conversationKey, instructions.size());
        tailParentUuids.put(conversationKey, parentUuid);
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
            tailParentUuids.remove(anyKey);
        }
    }

    private UUID persistMessages(long userId, UUID sessionUuid, UUID parentUuid, List<Message> messages) {
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
                    ChatMessageEntity entity = ChatMessageEntity.createTool(
                            uuid, userId, sessionUuid, parentUuid, "TOOL_CALL", ChatRole.TOOL_CALL, toToolCallJson(call));
                    chatMessageRepository.save(entity);
                    parentUuid = uuid;
                }
                continue;
            }

            if (message.getMessageType() == MessageType.TOOL && message instanceof ToolResponseMessage toolResponseMessage) {
                for (ToolResponseMessage.ToolResponse resp : toolResponseMessage.getResponses()) {
                    UUID uuid = UUID.randomUUID();
                    ChatMessageEntity entity = ChatMessageEntity.createTool(
                            uuid, userId, sessionUuid, parentUuid, "TOOL_RESULT", ChatRole.TOOL_RESULT, toToolResultJson(resp));
                    chatMessageRepository.save(entity);
                    parentUuid = uuid;
                }
            }
        }
        return parentUuid;
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

    /**
     * 取某次会话当前已落库的工具消息链尾 uuid，供阻塞调用方（如 AiAnalysePollingService）
     * 在 call() 返回后取用，作为紧接着要落库的 assistant 回复的 parentUuid。
     */
    public UUID getCurrentParentUuid(String conversationKey) {
        return tailParentUuids.get(conversationKey);
    }
}
