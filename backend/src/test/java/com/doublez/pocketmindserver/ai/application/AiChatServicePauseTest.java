package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.attachment.infra.persistence.vision.AttachmentVisionMapper;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.test.util.ReflectionTestUtils;
import reactor.core.Disposable;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Sinks;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * AiChatService 暂停流程单元测试。
 */
class AiChatServicePauseTest {

    private AiFailoverRouter aiFailoverRouter;
    private ChatSessionRepository chatSessionRepository;
    private ChatMessageRepository chatMessageRepository;
    private NoteRepository noteRepository;
    private AttachmentVisionMapper attachmentVisionMapper;
    private AiChatTitleService aiChatTitleService;
    private ChatStreamCancellationManager chatStreamCancellationManager;
    private ObjectMapper objectMapper;
    private ChatSseEventFactory chatSseEventFactory;
    private AiChatService aiChatService;

    @BeforeEach
    void setUp() {
        aiFailoverRouter = mock(AiFailoverRouter.class);
        chatSessionRepository = mock(ChatSessionRepository.class);
        chatMessageRepository = mock(ChatMessageRepository.class);
        noteRepository = mock(NoteRepository.class);
        attachmentVisionMapper = mock(AttachmentVisionMapper.class);
        aiChatTitleService = mock(AiChatTitleService.class);
        chatStreamCancellationManager = new ChatStreamCancellationManager();
        objectMapper = new ObjectMapper();
        chatSseEventFactory = new ChatSseEventFactory(objectMapper);

        aiChatService = new AiChatService(
                aiFailoverRouter,
                chatSessionRepository,
                chatMessageRepository,
                noteRepository,
                attachmentVisionMapper,
                aiChatTitleService,
                chatStreamCancellationManager,
                chatSseEventFactory
        );

        ReflectionTestUtils.setField(
                aiChatService,
                "globalSystemTemplate",
                new ByteArrayResource("system".getBytes(StandardCharsets.UTF_8))
        );
    }

    @Test
    void pause_withDelta_shouldPersistPartialAssistantAndEmitMessageUuid() throws Exception {
        long userId = 1L;
        UUID sessionUuid = UUID.randomUUID();
        String requestId = "req-pause-1";

        ChatSessionEntity session = ChatSessionEntity.create(sessionUuid, userId, null, "已命名会话");
        when(chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)).thenReturn(Optional.of(session));
        when(chatMessageRepository.findBySessionUuid(eq(userId), eq(sessionUuid), any(PageQuery.class)))
                .thenReturn(List.of());

        Sinks.Many<String> llmSink = Sinks.many().unicast().onBackpressureBuffer();
        when(aiFailoverRouter.executeChatStream(anyString(), any())).thenReturn(llmSink.asFlux());

        List<ServerSentEvent<String>> events = new CopyOnWriteArrayList<>();
        Disposable disposable = aiChatService
                .streamReply(userId, sessionUuid, "你好", List.of(), null, requestId)
                .subscribe(events::add);

        llmSink.tryEmitNext("部分回答");
        waitUntil(() -> hasEvent(events, "delta"), 2000);

        aiChatService.stopReply(userId, sessionUuid, requestId);
        waitUntil(() -> hasEvent(events, "paused"), 2000);

        ServerSentEvent<String> paused = findEvent(events, "paused");
        assertNotNull(paused);
        @SuppressWarnings("unchecked")
        Map<String, Object> payload = objectMapper.readValue(paused.data(), Map.class);
        assertEquals(requestId, payload.get("requestId"));
        assertTrue(payload.containsKey("messageUuid"));
        assertNotNull(payload.get("messageUuid"));

        ArgumentCaptor<ChatMessageEntity> captor = ArgumentCaptor.forClass(ChatMessageEntity.class);
        verify(chatMessageRepository, atLeast(2)).save(captor.capture());
        List<ChatMessageEntity> saved = captor.getAllValues();

        ChatMessageEntity userMessage = saved.get(0);
        assertEquals(ChatRole.USER, userMessage.getRole());
        assertEquals("你好", userMessage.getContent());

        ChatMessageEntity assistantMessage = saved.get(saved.size() - 1);
        assertEquals(ChatRole.ASSISTANT, assistantMessage.getRole());
        assertEquals("部分回答", assistantMessage.getContent());

        disposable.dispose();
    }

    @Test
    void pause_withoutDelta_shouldNotPersistEmptyAssistant() throws Exception {
        long userId = 1L;
        UUID sessionUuid = UUID.randomUUID();
        String requestId = "req-pause-2";

        ChatSessionEntity session = ChatSessionEntity.create(sessionUuid, userId, null, "已命名会话");
        when(chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)).thenReturn(Optional.of(session));
        when(chatMessageRepository.findBySessionUuid(eq(userId), eq(sessionUuid), any(PageQuery.class)))
                .thenReturn(List.of());

        Sinks.Many<String> llmSink = Sinks.many().unicast().onBackpressureBuffer();
        when(aiFailoverRouter.executeChatStream(anyString(), any())).thenReturn(llmSink.asFlux());

        List<ServerSentEvent<String>> events = new CopyOnWriteArrayList<>();
        Disposable disposable = aiChatService
                .streamReply(userId, sessionUuid, "你好", List.of(), null, requestId)
                .subscribe(events::add);

        aiChatService.stopReply(userId, sessionUuid, requestId);
        waitUntil(() -> hasEvent(events, "paused"), 2000);

        ServerSentEvent<String> paused = findEvent(events, "paused");
        assertNotNull(paused);
        @SuppressWarnings("unchecked")
        Map<String, Object> payload = objectMapper.readValue(paused.data(), Map.class);
        assertEquals(requestId, payload.get("requestId"));
        assertFalse(payload.containsKey("messageUuid"));

        verify(chatMessageRepository, times(1)).save(any(ChatMessageEntity.class));

        disposable.dispose();
    }

    private void waitUntil(Supplier<Boolean> condition, long timeoutMillis) throws InterruptedException {
        long start = System.currentTimeMillis();
        while (System.currentTimeMillis() - start < timeoutMillis) {
            if (condition.get()) {
                return;
            }
            Thread.sleep(20);
        }
        fail("等待条件超时");
    }

    private boolean hasEvent(List<ServerSentEvent<String>> events, String eventName) {
        return events.stream().anyMatch(e -> eventName.equals(e.event()));
    }

    private ServerSentEvent<String> findEvent(List<ServerSentEvent<String>> events, String eventName) {
        return events.stream().filter(e -> eventName.equals(e.event())).findFirst().orElse(null);
    }
}
