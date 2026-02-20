package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * analyse 场景下的会话/消息初始化（事务边界）。
 */
@Slf4j
@Service
public class AiAnalyseChatSessionService {

    private final ChatSessionRepository chatSessionRepository;
    private final ChatMessageRepository chatMessageRepository;

    public AiAnalyseChatSessionService(ChatSessionRepository chatSessionRepository,
                                      ChatMessageRepository chatMessageRepository) {
        this.chatSessionRepository = chatSessionRepository;
        this.chatMessageRepository = chatMessageRepository;
    }

        @Transactional
        public UUID createSessionWithMessages(UUID noteUuid,
                         long userId,
                         String title,
                         String userQuestion,
                         String assistantContent) {
        UUID sessionUuid = UUID.randomUUID();
        String finalTitle = (title != null && !title.isBlank()) ? title : "";

        ChatSessionEntity session = ChatSessionEntity.create(sessionUuid, userId, noteUuid, finalTitle);
        chatSessionRepository.save(session);

        UUID userMessageUuid = UUID.randomUUID();
        ChatMessageEntity userMessage = ChatMessageEntity.create(
            userMessageUuid,
            userId,
            sessionUuid,
            ChatRole.USER,
            userQuestion,
            List.of()
        );
        chatMessageRepository.save(userMessage);

        UUID assistantMessageUuid = UUID.randomUUID();
        ChatMessageEntity assistantMessage = ChatMessageEntity.create(
            assistantMessageUuid,
            userId,
            sessionUuid,
            ChatRole.ASSISTANT,
            assistantContent == null ? "" : assistantContent,
            List.of()
        );
        chatMessageRepository.save(assistantMessage);

        log.info("analyse chat session created: userId={}, sessionUuid={}, noteUuid={}", userId, sessionUuid, noteUuid);
        return sessionUuid;
        }

    @Transactional
    public void updateMemorySnapshot(long userId, UUID sessionUuid, String memorySnapshot) {
        Optional<ChatSessionEntity> sessionOpt = chatSessionRepository.findByUuidAndUserId(sessionUuid, userId);
        if (sessionOpt.isEmpty()) {
            log.warn("chat session not found for memory snapshot update: userId={}, sessionUuid={}", userId, sessionUuid);
            return;
        }
        ChatSessionEntity session = sessionOpt.get();
        session.updateMemorySnapshot(memorySnapshot);
        chatSessionRepository.update(session);
    }
}
