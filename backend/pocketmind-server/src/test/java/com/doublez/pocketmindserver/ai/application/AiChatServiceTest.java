package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
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
    @Mock private AttachmentVisionRepository attachmentVisionRepository;

    private AiChatService service;
        private ChatStreamCancellationManager chatStreamCancellationManager;
        private ChatSseEventFactory chatSseEventFactory;

    private static final long   USER_ID            = 100L;
    private static final UUID   SESSION_UUID       = UUID.randomUUID();
    private static final UUID   USER_MSG_UUID      = UUID.randomUUID();
    private static final UUID   ASSISTANT_MSG_UUID = UUID.randomUUID();

    @BeforeEach
    void setUp() throws Exception {
        chatStreamCancellationManager = new ChatStreamCancellationManager();
        chatSseEventFactory = new ChatSseEventFactory(new ObjectMapper());
        service = new AiChatService(
                aiFailoverRouter,
                chatSessionRepository,
                chatMessageRepository,
                noteRepository,
                attachmentVisionRepository,
                chatStreamCancellationManager,
                chatSseEventFactory);
        injectResource("globalSystemTemplate",      "global system prompt");
        injectResource("noteSystemTemplate",        "note system prompt");
        injectResource("branchAliasSystemTemplate", "branch alias system prompt");
        injectResource("branchAliasUserTemplate",   "<contextPrefix>user: <userMessage>");
    }

    private void injectResource(String fieldName, String content) throws Exception {
        Field field = AiChatService.class.getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(service, new ByteArrayResource(content.getBytes()));
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
