package com.doublez.pocketmindserver.ai.context;

import com.doublez.pocketmindserver.agui.AgUiEvent;
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
import reactor.core.publisher.Sinks;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/**
 * 观察工具调用循环的每一轮请求，把新增的 tool_call/tool_result 落库为 chat_messages，
 * 并（若调用方挂载了事件 sink）实时发出对应的 AG-UI 工具事件供 SSE 转发。
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
 *
 * 事件粒度上的已知简化：框架托管的工具调用循环只在"整轮工具调用+结果都已产生"之后才把
 * 增量历史交给这个 advisor，拿不到参数级的中间 chunk，所以 TOOL_CALL_START/END 几乎是背靠背
 * 发出的，不发 TOOL_CALL_ARGS。需要参数级进度的话，要切到用户托管的手动聚合循环。
 */
@Slf4j
public class PersistingToolCallAdvisor implements CallAdvisor, StreamAdvisor {

    public static final String CTX_CONVERSATION_KEY = "pm.persist.conversationKey";
    public static final String CTX_USER_ID = "pm.persist.userId";
    public static final String CTX_SESSION_UUID = "pm.persist.sessionUuid";
    public static final String CTX_PARENT_UUID = "pm.persist.parentUuid";
    public static final String CTX_EVENT_SINK = "pm.persist.eventSink";

    private static final int MAX_TRACKED_CONVERSATIONS = 200;

    /** A2UI 消息里"恰好一个"的顶层动作键，跟 genui 客户端做的强制校验对齐。 */
    private static final Set<String> A2UI_ACTION_KEYS =
            Set.of("createSurface", "updateComponents", "updateDataModel", "deleteSurface");

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

        @SuppressWarnings("unchecked")
        Sinks.Many<AgUiEvent> eventSink = (Sinks.Many<AgUiEvent>) ctx.get(CTX_EVENT_SINK);

        List<Message> delta = instructions.subList(lastSize, instructions.size());
        parentUuid = persistMessages(userId, sessionUuid, parentUuid, delta, eventSink);

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

    private UUID persistMessages(long userId, UUID sessionUuid, UUID parentUuid, List<Message> messages,
                                 Sinks.Many<AgUiEvent> eventSink) {
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
                    emit(eventSink, new AgUiEvent.ToolCallStart(call.id(), call.name()));
                    emit(eventSink, new AgUiEvent.ToolCallEnd(call.id()));
                }
                continue;
            }

            if (message.getMessageType() == MessageType.TOOL && message instanceof ToolResponseMessage toolResponseMessage) {
                for (ToolResponseMessage.ToolResponse resp : toolResponseMessage.getResponses()) {
                    UUID uuid = UUID.randomUUID();
                    // 落库内容跟事件类型无关：不管这次结果要不要发 ACTIVITY_SNAPSHOT，
                    // 都只存这一条 TOOL_RESULT，content 是工具的完整原始返回值。
                    ChatMessageEntity entity = ChatMessageEntity.createTool(
                            uuid, userId, sessionUuid, parentUuid, "TOOL_RESULT", ChatRole.TOOL_RESULT, toToolResultJson(resp));
                    chatMessageRepository.save(entity);
                    parentUuid = uuid;

                    Object a2uiEnvelope = tryParseA2uiEnvelope(resp.responseData());
                    if (a2uiEnvelope != null) {
                        emit(eventSink, new AgUiEvent.ActivitySnapshot(uuid.toString(), "a2ui-surface", a2uiEnvelope));
                    } else {
                        emit(eventSink, new AgUiEvent.ToolCallResult(uuid.toString(), resp.id(), toContentString(resp.responseData())));
                    }
                }
            }
        }
        return parentUuid;
    }

    private void emit(Sinks.Many<AgUiEvent> eventSink, AgUiEvent event) {
        if (eventSink != null) {
            eventSink.tryEmitNext(event);
        }
    }

    private String toContentString(Object responseData) {
        if (responseData instanceof String s) {
            return s;
        }
        return writeJson(responseData);
    }

    /**
     * 判断工具的原始返回值是不是一张 A2UI 卡片（而非普通工具的文本结果）。
     * 只做轻量校验：能解析成 JSON，且每条消息都带 version=v0.9 和恰好一个
     * 顶层动作键——这是 genui 客户端严格校验的最小子集，够用来区分卡片工具
     * 和普通工具，不需要照抄客户端完整的组件 schema 校验。
     *
     * <p>兼容单条消息（Map）和多条消息组成的数组（List）两种落地形状：
     * 一张完整卡片通常要 createSurface + updateComponents 两条消息才能显示
     * 内容，卡片工具会把它们打包成数组一起返回。
     */
    private Object tryParseA2uiEnvelope(String responseData) {
        if (responseData == null || responseData.isBlank()) {
            return null;
        }
        Object json;
        try {
            json = objectMapper.readValue(responseData, Object.class);
        } catch (Exception e) {
            return null;
        }
        if (json instanceof List<?> messages) {
            if (!messages.isEmpty() && messages.stream().allMatch(this::isA2uiMessage)) {
                return json;
            }
            return null;
        }
        return isA2uiMessage(json) ? json : null;
    }

    private boolean isA2uiMessage(Object json) {
        if (!(json instanceof Map<?, ?> map)) {
            return false;
        }
        if (!"v0.9".equals(map.get("version"))) {
            return false;
        }
        long actionKeyCount = map.keySet().stream()
                .filter(A2UI_ACTION_KEYS::contains)
                .count();
        return actionKeyCount == 1;
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
