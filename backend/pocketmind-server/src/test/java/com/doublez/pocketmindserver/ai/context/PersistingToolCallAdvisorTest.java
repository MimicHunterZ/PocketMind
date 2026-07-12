package com.doublez.pocketmindserver.ai.context;

import com.doublez.pocketmindserver.agui.AgUiEvent;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;
import org.springframework.ai.chat.client.ChatClientRequest;
import org.springframework.ai.chat.client.ChatClientResponse;
import org.springframework.ai.chat.client.advisor.api.CallAdvisorChain;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.ToolResponseMessage;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.prompt.Prompt;
import reactor.core.publisher.Sinks;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class PersistingToolCallAdvisorTest {

    private final ChatMessageRepository chatMessageRepository = Mockito.mock(ChatMessageRepository.class);
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final PersistingToolCallAdvisor advisor =
            new PersistingToolCallAdvisor(chatMessageRepository, objectMapper);

    @Test
    void plainToolResult_emitsToolCallResultAndPersistsOneMessage() {
        List<AgUiEvent> emitted = new ArrayList<>();
        Sinks.Many<AgUiEvent> sink = Sinks.many().multicast().onBackpressureBuffer();
        sink.asFlux().subscribe(emitted::add);

        adviseWithToolResponse(sink, "searchMemories", "未找到相关记忆。");

        ArgumentCaptor<ChatMessageEntity> captor = ArgumentCaptor.forClass(ChatMessageEntity.class);
        Mockito.verify(chatMessageRepository, Mockito.times(2)).save(captor.capture());
        List<ChatMessageEntity> saved = captor.getAllValues();
        assertThat(saved).hasSize(2);
        assertThat(saved.get(1).getRole()).isEqualTo(ChatRole.TOOL_RESULT);
        assertThat(saved.get(1).getMessageType()).isEqualTo("TOOL_RESULT");

        assertThat(emitted).hasSize(3); // ToolCallStart + ToolCallEnd + ToolCallResult
        assertThat(emitted.get(2)).isInstanceOf(AgUiEvent.ToolCallResult.class);
        var resultEvent = (AgUiEvent.ToolCallResult) emitted.get(2);
        assertThat(resultEvent.content()).isEqualTo("未找到相关记忆。");
    }

    @Test
    void a2uiEnvelopeToolResult_emitsActivitySnapshotInsteadOfToolCallResult() {
        List<AgUiEvent> emitted = new ArrayList<>();
        Sinks.Many<AgUiEvent> sink = Sinks.many().multicast().onBackpressureBuffer();
        sink.asFlux().subscribe(emitted::add);

        String a2uiJson = """
                [
                  {"version":"v0.9","createSurface":{"surfaceId":"card-1","catalogId":"https://a2ui.org/specification/v0_9/basic_catalog.json"}},
                  {"version":"v0.9","updateComponents":{"surfaceId":"card-1","components":[]}}
                ]
                """;

        adviseWithToolResponse(sink, "renderChoiceCard", a2uiJson);

        // 落库行为不变：不管发不发 ACTIVITY_SNAPSHOT，都只存一条 TOOL_RESULT
        ArgumentCaptor<ChatMessageEntity> captor = ArgumentCaptor.forClass(ChatMessageEntity.class);
        Mockito.verify(chatMessageRepository, Mockito.times(2)).save(captor.capture());
        List<ChatMessageEntity> saved = captor.getAllValues();
        assertThat(saved.stream().filter(e -> e.getRole() == ChatRole.TOOL_RESULT)).hasSize(1);

        assertThat(emitted).hasSize(3); // ToolCallStart + ToolCallEnd + ActivitySnapshot
        assertThat(emitted).noneMatch(e -> e instanceof AgUiEvent.ToolCallResult);
        assertThat(emitted.get(2)).isInstanceOf(AgUiEvent.ActivitySnapshot.class);
        var snapshot = (AgUiEvent.ActivitySnapshot) emitted.get(2);
        assertThat(snapshot.activityType()).isEqualTo("a2ui-surface");
        assertThat(snapshot.content()).isInstanceOf(List.class);
    }

    @Test
    void knownHistoricalToolCallId_isSkippedNotPersistedAgain() {
        List<AgUiEvent> emitted = new ArrayList<>();
        Sinks.Many<AgUiEvent> sink = Sinks.many().multicast().onBackpressureBuffer();
        sink.asFlux().subscribe(emitted::add);

        UserMessage userMessage = new UserMessage("刚才选的是哪个？");
        AssistantMessage historicalCall = AssistantMessage.builder()
                .content("")
                .toolCalls(List.of(new AssistantMessage.ToolCall("call-1", "function", "searchMemories", "{}")))
                .build();
        ToolResponseMessage historicalResult = ToolResponseMessage.builder()
                .responses(List.of(new ToolResponseMessage.ToolResponse("call-1", "searchMemories", "上次的结果")))
                .build();

        List<Message> instructions = List.of(userMessage, historicalCall, historicalResult);
        Map<String, Object> context = Map.of(
                PersistingToolCallAdvisor.CTX_CONVERSATION_KEY, "conv-2",
                PersistingToolCallAdvisor.CTX_USER_ID, 42L,
                PersistingToolCallAdvisor.CTX_SESSION_UUID, UUID.randomUUID(),
                PersistingToolCallAdvisor.CTX_EVENT_SINK, sink,
                PersistingToolCallAdvisor.CTX_KNOWN_TOOL_CALL_IDS, Set.of("call-1")
        );
        ChatClientRequest request = new ChatClientRequest(new Prompt(instructions), context);

        CallAdvisorChain chain = Mockito.mock(CallAdvisorChain.class);
        Mockito.when(chain.nextCall(Mockito.any())).thenReturn(Mockito.mock(ChatClientResponse.class));

        advisor.adviseCall(request, chain);

        Mockito.verify(chatMessageRepository, Mockito.never()).save(Mockito.any());
        assertThat(emitted).isEmpty();
    }

    @Test
    void interleavedTextBeforeToolCall_persistedAsTextMessageBeforeToolCall() {
        List<AgUiEvent> emitted = new ArrayList<>();
        Sinks.Many<AgUiEvent> sink = Sinks.many().multicast().onBackpressureBuffer();
        sink.asFlux().subscribe(emitted::add);

        // 模型在调用工具前先说了一段话，且这段话和 toolCall 在同一条 AssistantMessage 上。
        UserMessage userMessage = new UserMessage("给我生成一个选择卡片");
        AssistantMessage assistantMessage = AssistantMessage.builder()
                .content("让我先了解一下你的饮食偏好。")
                .toolCalls(List.of(new AssistantMessage.ToolCall("call-1", "function", "renderChoiceCard", "{}")))
                .build();

        List<Message> instructions = List.of(userMessage, assistantMessage);
        Map<String, Object> context = Map.of(
                PersistingToolCallAdvisor.CTX_CONVERSATION_KEY, "conv-interleaved",
                PersistingToolCallAdvisor.CTX_USER_ID, 42L,
                PersistingToolCallAdvisor.CTX_SESSION_UUID, UUID.randomUUID(),
                PersistingToolCallAdvisor.CTX_EVENT_SINK, sink
        );
        ChatClientRequest request = new ChatClientRequest(new Prompt(instructions), context);
        CallAdvisorChain chain = Mockito.mock(CallAdvisorChain.class);
        Mockito.when(chain.nextCall(Mockito.any())).thenReturn(Mockito.mock(ChatClientResponse.class));

        advisor.adviseCall(request, chain);

        // 先落一条 ASSISTANT TEXT(工具前文本)，再落 TOOL_CALL，顺序保证 reload 时文本排在工具前。
        ArgumentCaptor<ChatMessageEntity> captor = ArgumentCaptor.forClass(ChatMessageEntity.class);
        Mockito.verify(chatMessageRepository, Mockito.times(2)).save(captor.capture());
        List<ChatMessageEntity> saved = captor.getAllValues();
        assertThat(saved.get(0).getRole()).isEqualTo(ChatRole.ASSISTANT);
        assertThat(saved.get(0).getMessageType()).isEqualTo("TEXT");
        assertThat(saved.get(0).getContent()).isEqualTo("让我先了解一下你的饮食偏好。");
        assertThat(saved.get(1).getRole()).isEqualTo(ChatRole.TOOL_CALL);
        // TOOL_CALL 的父节点是刚落的 TEXT 消息。
        assertThat(saved.get(1).getParentUuid()).isEqualTo(saved.get(0).getUuid());

        // 供终态去重用的"已落工具前文本"记录正确。
        assertThat(advisor.getPersistedInterleavedText("conv-interleaved"))
                .isEqualTo("让我先了解一下你的饮食偏好。");

        // 文本的流式呈现由 SseReplyService 的 TEXT_MESSAGE_CONTENT 负责，这里不重复发文本事件。
        assertThat(emitted).noneMatch(e -> e instanceof AgUiEvent.TextMessageContent);
    }

    @Test
    void blankInterleavedText_doesNotPersistEmptyTextMessage() {
        Sinks.Many<AgUiEvent> sink = Sinks.many().multicast().onBackpressureBuffer();
        // content 为空(现有多数场景)：只落 TOOL_CALL，不产生空 TEXT 消息。
        adviseWithToolResponse(sink, "searchMemories", "未找到相关记忆。");

        ArgumentCaptor<ChatMessageEntity> captor = ArgumentCaptor.forClass(ChatMessageEntity.class);
        Mockito.verify(chatMessageRepository, Mockito.times(2)).save(captor.capture());
        assertThat(captor.getAllValues()).noneMatch(e -> e.getMessageType().equals("TEXT"));
        assertThat(advisor.getPersistedInterleavedText("conv-1")).isEmpty();
    }

    private void adviseWithToolResponse(Sinks.Many<AgUiEvent> sink, String toolName, String responseData) {
        UserMessage userMessage = new UserMessage("帮我推荐几个选项");
        AssistantMessage assistantMessage = AssistantMessage.builder()
                .content("")
                .toolCalls(List.of(new AssistantMessage.ToolCall("call-1", "function", toolName, "{}")))
                .build();
        ToolResponseMessage toolResponseMessage = ToolResponseMessage.builder()
                .responses(List.of(new ToolResponseMessage.ToolResponse("call-1", toolName, responseData)))
                .build();

        List<Message> instructions = List.of(userMessage, assistantMessage, toolResponseMessage);
        Map<String, Object> context = Map.of(
                PersistingToolCallAdvisor.CTX_CONVERSATION_KEY, "conv-1",
                PersistingToolCallAdvisor.CTX_USER_ID, 42L,
                PersistingToolCallAdvisor.CTX_SESSION_UUID, UUID.randomUUID(),
                PersistingToolCallAdvisor.CTX_EVENT_SINK, sink
        );
        ChatClientRequest request = new ChatClientRequest(new Prompt(instructions), context);

        CallAdvisorChain chain = Mockito.mock(CallAdvisorChain.class);
        Mockito.when(chain.nextCall(Mockito.any())).thenReturn(Mockito.mock(ChatClientResponse.class));

        advisor.adviseCall(request, chain);
    }
}
