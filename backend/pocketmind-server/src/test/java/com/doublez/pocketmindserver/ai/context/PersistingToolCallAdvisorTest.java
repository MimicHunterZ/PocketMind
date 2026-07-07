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
                  {"version":"v0.9","createSurface":{"surfaceId":"card-1","catalogId":"https://a2ui.org/specification/v0_9/standard_catalog.json"}},
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
