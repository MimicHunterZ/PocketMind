package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.application.context.ContextAssembler;
import com.doublez.pocketmindserver.ai.application.embedding.EmbeddingService;
import com.doublez.pocketmindserver.ai.application.memory.MemoryInjector;
import com.doublez.pocketmindserver.ai.application.memory.MemoryQueryServiceImpl;
import com.doublez.pocketmindserver.ai.application.retrieval.AnalyzedIntent;
import com.doublez.pocketmindserver.ai.application.retrieval.IntentAnalyzer;
import com.doublez.pocketmindserver.ai.application.retrieval.RetrievalOrchestrator;
import com.doublez.pocketmindserver.ai.application.stream.ChatSseEventFactory;
import com.doublez.pocketmindserver.ai.application.stream.ChatStreamCancellationManager;
import com.doublez.pocketmindserver.ai.application.stream.SseReplyService;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.ai.tool.skill.TenantSkillToolResolver;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageType;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.user.application.UserSettingService;
import com.doublez.pocketmindserver.memory.application.InMemoryMemoryRecordRepository;
import com.doublez.pocketmindserver.resource.application.ChatTranscriptResourceSyncService;
import com.doublez.pocketmind.common.web.BusinessException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpStatus;

import java.lang.reflect.Field;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * AiChatService unit tests.
 * All external dependencies are mocked; only business logic branches are covered.
 */
@ExtendWith(MockitoExtension.class)
class AiChatServiceTest {

    @Mock private AiFailoverRouter         aiFailoverRouter;
    @Mock private ChatSessionRepository    chatSessionRepository;
    @Mock private ChatMessageRepository    chatMessageRepository;
    @Mock private NoteRepository           noteRepository;
        @Mock private ChatTranscriptResourceSyncService chatTranscriptResourceSyncService;
        @Mock private com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository resourceRecordRepository;
    @Mock private AttachmentVisionRepository attachmentVisionRepository;
        @Mock private TenantSkillToolResolver tenantSkillToolResolver;

    private AiChatService service;
        private ChatStreamCancellationManager chatStreamCancellationManager;
        private ChatSseEventFactory chatSseEventFactory;
                private ContextAssembler contextAssembler;
                private SseReplyService sseReplyService;
        private UserSettingService userSettingService;
        private IntentAnalyzer intentAnalyzer;
        private RetrievalOrchestrator retrievalOrchestrator;

    private static final long   USER_ID            = 100L;
    private static final UUID   SESSION_UUID       = UUID.randomUUID();
    private static final UUID   USER_MSG_UUID      = UUID.randomUUID();
    private static final UUID   ASSISTANT_MSG_UUID = UUID.randomUUID();

    @BeforeEach
    void setUp() throws Exception {
        chatStreamCancellationManager = new ChatStreamCancellationManager();
        chatSseEventFactory = new ChatSseEventFactory(new com.doublez.pocketmindserver.agui.AgUiEventEncoder(new ObjectMapper()));
        userSettingService = org.mockito.Mockito.mock(UserSettingService.class);
        lenient().when(userSettingService.getActivePersonaPrompt(anyLong())).thenReturn("");
        intentAnalyzer = mock(IntentAnalyzer.class);
        retrievalOrchestrator = mock(RetrievalOrchestrator.class);
        lenient().when(intentAnalyzer.analyze(anyString())).thenReturn(AnalyzedIntent.skip("单元测试默认跳过检索"));
        com.doublez.pocketmindserver.ai.application.context.ContextDataRetriever retriever = new com.doublez.pocketmindserver.ai.application.context.ContextDataRetriever(
                noteRepository,
                attachmentVisionRepository,
                resourceRecordRepository,
                                new MemoryQueryServiceImpl(mock(EmbeddingService.class), new com.doublez.pocketmindserver.memory.application.MemoryContextService() {
                    @Override
                    public com.doublez.pocketmindserver.context.domain.ContextUri userMemoryRoot(long userId) {
                        return com.doublez.pocketmindserver.context.domain.ContextUri.userMemoriesRoot(userId);
                    }

                    @Override
                    public com.doublez.pocketmindserver.context.domain.ContextUri userMemoryByType(long userId,
                                                                                                     com.doublez.pocketmindserver.memory.domain.MemoryType memoryType) {
                        return com.doublez.pocketmindserver.context.domain.ContextUri.userMemoriesRoot(userId)
                                .child(memoryType.name().toLowerCase());
                    }
                }, new InMemoryMemoryRecordRepository()),
                retrievalOrchestrator,
                intentAnalyzer
        );
        contextAssembler = new ContextAssembler(
                retriever,
                userSettingService
        );
        com.doublez.pocketmindserver.resource.application.tool.ResourceToolSet.ResourceToolSetFactory resourceToolSetFactory = mock(com.doublez.pocketmindserver.resource.application.tool.ResourceToolSet.ResourceToolSetFactory.class);
        com.doublez.pocketmindserver.resource.application.tool.ResourceToolSet mockResourceToolSet = mock(com.doublez.pocketmindserver.resource.application.tool.ResourceToolSet.class);
        lenient().when(mockResourceToolSet.toToolCallbacks()).thenReturn(new org.springframework.ai.tool.ToolCallback[0]);
        lenient().when(resourceToolSetFactory.createForUser(anyLong())).thenReturn(mockResourceToolSet);

        sseReplyService = new SseReplyService(
                aiFailoverRouter,
                chatMessageRepository,
                chatStreamCancellationManager,
                chatSseEventFactory,
                tenantSkillToolResolver,
                chatTranscriptResourceSyncService,
                new com.doublez.pocketmindserver.memory.application.MemoryToolSet.MemoryToolSetFactory(
                        new InMemoryMemoryRecordRepository()),
                null,  // SessionCommitService — 单元测试不触发会话提交
                resourceToolSetFactory,
                new com.doublez.pocketmindserver.ai.application.tool.A2uiChoiceCardToolSet.A2uiChoiceCardToolSetFactory(new ObjectMapper()),
                new com.doublez.pocketmindserver.ai.context.PersistingToolCallAdvisor(chatMessageRepository, new ObjectMapper())
        );
        service = new AiChatService(
                chatSessionRepository,
                chatMessageRepository,
                contextAssembler,
                sseReplyService,
                chatTranscriptResourceSyncService,
                new ObjectMapper());
        lenient().when(tenantSkillToolResolver.resolveForUser(anyLong(), anyString()))
                .thenReturn(new TenantSkillToolResolver.ResolvedTenantSkillTool(
                        "user-100",
                        "claude",
                        null,
                        java.util.Map.of("tenantKey", "user-100", "agentKey", "claude")
                ));
        injectResource(contextAssembler, "globalSystemTemplate", "<if(persona)><persona><else>你是 PocketMind 的 AI 助手，是用户的第二大脑伙伴。<endif>\n## ⚠️ 强制底层行为准则");
                injectResource(contextAssembler, "noteSystemTemplate", "<if(persona)><persona><else>你是 PocketMind 的 AI 笔记助手，是用户的第二大脑伙伴。<endif>\n<if(noteTitle)><noteTitle><endif>");
        injectResource(sseReplyService, "branchAliasSystemTemplate", "branch alias system prompt");
        injectResource(sseReplyService, "branchAliasUserTemplate", "<contextPrefix>user: <userMessage>");
    }
        @Nested
        class SystemPersonaTest {

                @Test
                void customPersona_shouldOverrideDefaultPersona() {
                        when(userSettingService.getActivePersonaPrompt(USER_ID)).thenReturn("用户自定义人设");

                        String systemPrompt = contextAssembler.buildSystemPrompt(USER_ID, makeSession(), "你好");

                        assertTrue(systemPrompt.contains("用户自定义人设"));
                }

                @Test
                void emptyCustomPersona_shouldFallbackToDefaultGlobalPersona() {
                        when(userSettingService.getActivePersonaPrompt(USER_ID)).thenReturn("   ");

                        String systemPrompt = contextAssembler.buildSystemPrompt(USER_ID, makeSession(), "你好");

                        assertTrue(systemPrompt.contains("第二大脑"));
                        assertTrue(systemPrompt.contains("## ⚠️ 强制底层行为准则"));
                }
        }

        private void injectResource(Object target, String fieldName, String content) throws Exception {
                Field field = target.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
                field.set(target, new ByteArrayResource(content.getBytes()));
    }

    // =========================================================================
    // editUserMessage
    // =========================================================================

    @Nested
    class EditUserMessageTest {

        @Test
        void lastMessage_noGrandchildren_allowsEdit() {
            ChatMessageEntity assistantChild = makeAssistant(ASSISTANT_MSG_UUID, USER_MSG_UUID);
            when(chatMessageRepository.findChildrenByParentUuid(USER_MSG_UUID, USER_ID))
                    .thenReturn(List.of(assistantChild));
            when(chatMessageRepository.findChildrenByParentUuid(ASSISTANT_MSG_UUID, USER_ID))
                    .thenReturn(List.of());

            assertDoesNotThrow(() ->
                    service.editUserMessage(USER_ID, USER_MSG_UUID, "updated content"));

            verify(chatMessageRepository).updateContent(USER_MSG_UUID, USER_ID, "updated content");
            verify(chatMessageRepository).softDeleteAssistantChildren(USER_MSG_UUID, USER_ID);
        }

        @Test
        void noAssistantChild_allowsEdit() {
            when(chatMessageRepository.findChildrenByParentUuid(USER_MSG_UUID, USER_ID))
                    .thenReturn(List.of());

            assertDoesNotThrow(() ->
                    service.editUserMessage(USER_ID, USER_MSG_UUID, "corrected content"));

            verify(chatMessageRepository).updateContent(USER_MSG_UUID, USER_ID, "corrected content");
            verify(chatMessageRepository).softDeleteAssistantChildren(USER_MSG_UUID, USER_ID);
        }

        @Test
        void nonLastMessage_hasUserGrandchild_throwsUnprocessableEntity() {
            UUID nextUserUuid  = UUID.randomUUID();
            ChatMessageEntity assistantChild = makeAssistant(ASSISTANT_MSG_UUID, USER_MSG_UUID);
            ChatMessageEntity userGrandchild = makeUser(nextUserUuid, ASSISTANT_MSG_UUID);

            when(chatMessageRepository.findChildrenByParentUuid(USER_MSG_UUID, USER_ID))
                    .thenReturn(List.of(assistantChild));
            when(chatMessageRepository.findChildrenByParentUuid(ASSISTANT_MSG_UUID, USER_ID))
                    .thenReturn(List.of(userGrandchild));

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    service.editUserMessage(USER_ID, USER_MSG_UUID, "illegal edit"));

            assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, ex.getStatus());
            verify(chatMessageRepository, never()).updateContent(any(), anyLong(), any());
            verify(chatMessageRepository, never()).softDeleteAssistantChildren(any(), anyLong());
        }

        @Test
        void multipleAssistantBranches_anyWithGrandchild_rejectsEdit() {
            UUID assistantA = UUID.randomUUID();
            UUID assistantB = UUID.randomUUID();
            UUID nextUser   = UUID.randomUUID();

            when(chatMessageRepository.findChildrenByParentUuid(USER_MSG_UUID, USER_ID))
                    .thenReturn(List.of(makeAssistant(assistantA, USER_MSG_UUID),
                                        makeAssistant(assistantB, USER_MSG_UUID)));
            when(chatMessageRepository.findChildrenByParentUuid(assistantA, USER_ID))
                    .thenReturn(List.of());
            when(chatMessageRepository.findChildrenByParentUuid(assistantB, USER_ID))
                    .thenReturn(List.of(makeUser(nextUser, assistantB)));

            assertThrows(BusinessException.class, () ->
                    service.editUserMessage(USER_ID, USER_MSG_UUID, "illegal"));

            verify(chatMessageRepository, never()).updateContent(any(), anyLong(), any());
        }
    }

    // =========================================================================
    // regenerateReply -- validation paths only
    // =========================================================================

    @Nested
    class ListMessagesTest {

        @Test
        void leafNull_shouldReturnLatestLeafChainOnly() {
            UUID user1 = UUID.randomUUID();
            UUID ai1 = UUID.randomUUID();
            UUID userA = UUID.randomUUID();
            UUID aiA = UUID.randomUUID();
            UUID userB = UUID.randomUUID();
            UUID aiB = UUID.randomUUID();

            when(chatSessionRepository.findByUuidAndUserId(SESSION_UUID, USER_ID))
                    .thenReturn(Optional.of(makeSession()));

            List<ChatMessageEntity> allMessages = List.of(
                    makeUser(user1, null),
                    makeAssistant(ai1, user1),
                    makeUser(userA, ai1),
                    makeAssistant(aiA, userA),
                    makeUser(userB, ai1),
                    makeAssistant(aiB, userB)
            );
            when(chatMessageRepository.findBySessionUuid(eq(USER_ID), eq(SESSION_UUID), any()))
                    .thenReturn(allMessages);

            List<ChatMessageEntity> latestBranchChain = List.of(
                    makeUser(user1, null),
                    makeAssistant(ai1, user1),
                    makeUser(userB, ai1),
                    makeAssistant(aiB, userB)
            );
            when(chatMessageRepository.findChain(aiB, USER_ID)).thenReturn(latestBranchChain);

            List<ChatMessageEntity> result = service.listMessages(USER_ID, SESSION_UUID, null);

            assertEquals(latestBranchChain, result);
            verify(chatMessageRepository).findChain(aiB, USER_ID);
        }

        @Test
        void leafNull_noMessages_shouldReturnEmptyList() {
            when(chatSessionRepository.findByUuidAndUserId(SESSION_UUID, USER_ID))
                    .thenReturn(Optional.of(makeSession()));
            when(chatMessageRepository.findBySessionUuid(eq(USER_ID), eq(SESSION_UUID), any()))
                    .thenReturn(List.of());

            List<ChatMessageEntity> result = service.listMessages(USER_ID, SESSION_UUID, null);

            assertTrue(result.isEmpty());
            verify(chatMessageRepository, never()).findChain(any(), anyLong());
        }
    }

    @Nested
    class RegenerateReplyValidationTest {

        @Test
        void sessionNotFound_throwsNotFound() {
            when(chatSessionRepository.findByUuidAndUserId(SESSION_UUID, USER_ID))
                    .thenReturn(Optional.empty());

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    service.regenerateReply(USER_ID, SESSION_UUID, USER_MSG_UUID, "req-1").blockFirst());

            assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
        }

        @Test
        void messageNotFound_throwsNotFound() {
            when(chatSessionRepository.findByUuidAndUserId(SESSION_UUID, USER_ID))
                    .thenReturn(Optional.of(makeSession()));
            when(chatMessageRepository.findByUuidAndUserId(USER_MSG_UUID, USER_ID))
                    .thenReturn(Optional.empty());

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    service.regenerateReply(USER_ID, SESSION_UUID, USER_MSG_UUID, "req-2").blockFirst());

            assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
        }

        @Test
        void assistantWithNullParent_throwsBadRequest() {
            ChatMessageEntity orphan = makeAssistant(ASSISTANT_MSG_UUID, null);

            when(chatSessionRepository.findByUuidAndUserId(SESSION_UUID, USER_ID))
                    .thenReturn(Optional.of(makeSession()));
            when(chatMessageRepository.findByUuidAndUserId(ASSISTANT_MSG_UUID, USER_ID))
                    .thenReturn(Optional.of(orphan));

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    service.regenerateReply(USER_ID, SESSION_UUID, ASSISTANT_MSG_UUID, "req-3").blockFirst());

            assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        }
    }

    // =========================================================================
    // rateMessage
    // =========================================================================

    @Nested
    class RateMessageTest {

        @Test
        void messageNotFound_throwsNotFound() {
            when(chatMessageRepository.findByUuidAndUserId(USER_MSG_UUID, USER_ID))
                    .thenReturn(Optional.empty());

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    service.rateMessage(USER_ID, USER_MSG_UUID, 1));

            assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
            verify(chatMessageRepository, never()).updateRating(any(), anyLong(), anyInt());
        }

        @Test
        void messageExists_updateRatingCalled() {
            when(chatMessageRepository.findByUuidAndUserId(USER_MSG_UUID, USER_ID))
                    .thenReturn(Optional.of(makeUser(USER_MSG_UUID, null)));

            assertDoesNotThrow(() -> service.rateMessage(USER_ID, USER_MSG_UUID, 1));

            verify(chatMessageRepository).updateRating(USER_MSG_UUID, USER_ID, 1);
        }
    }

    // =========================================================================
    // updateBranchAlias
    // =========================================================================

    @Nested
    class UpdateBranchAliasTest {

        @Test
        void messageNotFound_throwsNotFound() {
            when(chatMessageRepository.findByUuidAndUserId(ASSISTANT_MSG_UUID, USER_ID))
                    .thenReturn(Optional.empty());

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    service.updateBranchAlias(USER_ID, ASSISTANT_MSG_UUID, "new alias"));

            assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
            verify(chatMessageRepository, never()).updateBranchAlias(any(), anyLong(), any());
        }

        @Test
        void aliasTrimmed_beforePersist() {
            when(chatMessageRepository.findByUuidAndUserId(ASSISTANT_MSG_UUID, USER_ID))
                    .thenReturn(Optional.of(makeAssistant(ASSISTANT_MSG_UUID, USER_MSG_UUID)));

            service.updateBranchAlias(USER_ID, ASSISTANT_MSG_UUID, "  branch name  ");

            verify(chatMessageRepository).updateBranchAlias(ASSISTANT_MSG_UUID, USER_ID, "branch name");
        }
    }

    @Nested
    class ToSpringAiMessagesTest {

        @Test
        void toolCallAndResult_rebuildAsAssistantToolCallsPlusToolResponse() {
            UUID userUuid = UUID.randomUUID();
            UUID callUuid = UUID.randomUUID();
            UUID resultUuid = UUID.randomUUID();
            List<ChatMessageEntity> history = List.of(
                    makeUser(userUuid, null),
                    ChatMessageEntity.createTool(callUuid, USER_ID, SESSION_UUID, userUuid,
                            "TOOL_CALL", ChatRole.TOOL_CALL,
                            "{\"toolCallId\":\"call-1\",\"type\":\"function\",\"name\":\"searchMemories\",\"arguments\":\"{}\"}"),
                    ChatMessageEntity.createTool(resultUuid, USER_ID, SESSION_UUID, callUuid,
                            "TOOL_RESULT", ChatRole.TOOL_RESULT,
                            "{\"toolCallId\":\"call-1\",\"name\":\"searchMemories\",\"result\":\"未找到相关记忆。\"}")
            );

            List<org.springframework.ai.chat.messages.Message> messages = service.toSpringAiMessages(history);

            assertEquals(3, messages.size());
            assertInstanceOf(org.springframework.ai.chat.messages.UserMessage.class, messages.get(0));
            var assistant = (org.springframework.ai.chat.messages.AssistantMessage) messages.get(1);
            assertEquals(1, assistant.getToolCalls().size());
            assertEquals("call-1", assistant.getToolCalls().get(0).id());
            assertEquals("searchMemories", assistant.getToolCalls().get(0).name());
            var toolResponse = (org.springframework.ai.chat.messages.ToolResponseMessage) messages.get(2);
            assertEquals(1, toolResponse.getResponses().size());
            assertEquals("call-1", toolResponse.getResponses().get(0).id());
            assertEquals("未找到相关记忆。", toolResponse.getResponses().get(0).responseData());
        }

        @Test
        void multipleToolCallsInSameTurn_groupIntoOneAssistantAndOneToolResponse() {
            UUID userUuid = UUID.randomUUID();
            UUID call1 = UUID.randomUUID();
            UUID call2 = UUID.randomUUID();
            UUID result1 = UUID.randomUUID();
            UUID result2 = UUID.randomUUID();
            List<ChatMessageEntity> history = List.of(
                    makeUser(userUuid, null),
                    ChatMessageEntity.createTool(call1, USER_ID, SESSION_UUID, userUuid,
                            "TOOL_CALL", ChatRole.TOOL_CALL,
                            "{\"toolCallId\":\"call-1\",\"type\":\"function\",\"name\":\"a\",\"arguments\":\"{}\"}"),
                    ChatMessageEntity.createTool(call2, USER_ID, SESSION_UUID, call1,
                            "TOOL_CALL", ChatRole.TOOL_CALL,
                            "{\"toolCallId\":\"call-2\",\"type\":\"function\",\"name\":\"b\",\"arguments\":\"{}\"}"),
                    ChatMessageEntity.createTool(result1, USER_ID, SESSION_UUID, call2,
                            "TOOL_RESULT", ChatRole.TOOL_RESULT,
                            "{\"toolCallId\":\"call-1\",\"name\":\"a\",\"result\":\"结果一\"}"),
                    ChatMessageEntity.createTool(result2, USER_ID, SESSION_UUID, result1,
                            "TOOL_RESULT", ChatRole.TOOL_RESULT,
                            "{\"toolCallId\":\"call-2\",\"name\":\"b\",\"result\":\"结果二\"}")
            );

            List<org.springframework.ai.chat.messages.Message> messages = service.toSpringAiMessages(history);

            assertEquals(3, messages.size());
            var assistant = (org.springframework.ai.chat.messages.AssistantMessage) messages.get(1);
            assertEquals(2, assistant.getToolCalls().size());
            var toolResponse = (org.springframework.ai.chat.messages.ToolResponseMessage) messages.get(2);
            assertEquals(2, toolResponse.getResponses().size());
        }

        @Test
        void textOnlyHistory_unaffected() {
            UUID userUuid = UUID.randomUUID();
            UUID assistantUuid = UUID.randomUUID();
            List<ChatMessageEntity> history = List.of(
                    makeUser(userUuid, null),
                    makeAssistant(assistantUuid, userUuid)
            );

            List<org.springframework.ai.chat.messages.Message> messages = service.toSpringAiMessages(history);

            assertEquals(2, messages.size());
            assertInstanceOf(org.springframework.ai.chat.messages.UserMessage.class, messages.get(0));
            assertInstanceOf(org.springframework.ai.chat.messages.AssistantMessage.class, messages.get(1));
        }
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private ChatMessageEntity makeUser(UUID uuid, UUID parentUuid) {
        return ChatMessageEntity.create(uuid, USER_ID, SESSION_UUID, parentUuid,
                ChatRole.USER, "user message", null);
    }

    private ChatMessageEntity makeAssistant(UUID uuid, UUID parentUuid) {
        return ChatMessageEntity.create(uuid, USER_ID, SESSION_UUID, parentUuid,
                ChatRole.ASSISTANT, "ai response", null);
    }

    private ChatSessionEntity makeSession() {
        return ChatSessionEntity.create(SESSION_UUID, USER_ID, null, "test session");
    }
}
