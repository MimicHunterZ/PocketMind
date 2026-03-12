package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 默认聊天转录 Resource 同步服务实现。
 */
@Service
public class ChatTranscriptResourceSyncServiceImpl implements ChatTranscriptResourceSyncService {

    private final ChatMessageRepository chatMessageRepository;
    private final ChatSessionRepository chatSessionRepository;
    private final ResourceRecordRepository resourceRecordRepository;
    private final ResourceContextService resourceContextService;
    private final ResourceCatalogSyncService catalogSyncService;

    /** 对话转录消息条目模板 */
    @Value("classpath:prompts/chat/transcript_message.md")
    private Resource transcriptMessageTemplate;

    public ChatTranscriptResourceSyncServiceImpl(ChatMessageRepository chatMessageRepository,
                                                 ChatSessionRepository chatSessionRepository,
                                                 ResourceRecordRepository resourceRecordRepository,
                                                 ResourceContextService resourceContextService,
                                                 ResourceCatalogSyncService catalogSyncService) {
        this.chatMessageRepository = chatMessageRepository;
        this.chatSessionRepository = chatSessionRepository;
        this.resourceRecordRepository = resourceRecordRepository;
        this.resourceContextService = resourceContextService;
        this.catalogSyncService = catalogSyncService;
    }

    @Override
    @Transactional
    public void syncSessionTranscript(long userId, UUID sessionUuid) {
        List<ChatMessageEntity> messages = chatMessageRepository.findBySessionUuid(
                userId,
                sessionUuid,
                PageQuery.unbounded(1000)
        ).stream()
            .filter(message -> !message.isDeleted())
                .filter(message -> "TEXT".equals(message.getMessageType()))
                .filter(message -> message.getRole() == ChatRole.USER || message.getRole() == ChatRole.ASSISTANT)
                .filter(message -> message.getContent() != null && !message.getContent().isBlank())
                .toList();

        List<ResourceRecordEntity> existing = findTranscriptResources(userId, sessionUuid);
        if (messages.isEmpty()) {
            softDeleteResources(existing);
            return;
        }

        String title = chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .map(session -> session.getTitle() == null || session.getTitle().isBlank() ? "对话记录" : session.getTitle())
                .orElse("对话记录");
        String transcript = renderTranscript(messages);

        if (existing.isEmpty()) {
            ResourceRecordEntity resource = ResourceRecordEntity.createChatTranscript(
                    UUID.randomUUID(),
                    userId,
                    sessionUuid,
                    resourceContextService.chatTranscriptResource(userId, sessionUuid),
                    title,
                    transcript
            );
            resourceRecordRepository.save(resource);
            catalogSyncService.syncToCatalog(resource);
            return;
        }

        ResourceRecordEntity resource = existing.getFirst();
        resource.updateContent(title, transcript);
        resourceRecordRepository.update(resource);
        catalogSyncService.syncToCatalog(resource);
    }

    @Override
    @Transactional
    public void softDeleteBySession(long userId, UUID sessionUuid) {
        softDeleteResources(findTranscriptResources(userId, sessionUuid));
    }

    private List<ResourceRecordEntity> findTranscriptResources(long userId, UUID sessionUuid) {
        return resourceRecordRepository.findBySessionUuid(userId, sessionUuid).stream()
                .filter(resource -> resource.getSourceType() == ResourceSourceType.CHAT_TRANSCRIPT)
                .toList();
    }

    private void softDeleteResources(List<ResourceRecordEntity> resources) {
        for (ResourceRecordEntity resource : resources) {
            resource.softDelete();
            resourceRecordRepository.update(resource);
            catalogSyncService.removeFromCatalog(resource);
        }
    }

    private String renderTranscript(List<ChatMessageEntity> messages) {
        return messages.stream()
                .map(message -> {
                    try {
                        return PromptBuilder.render(transcriptMessageTemplate, Map.of(
                                "role", message.getRole() == ChatRole.USER ? "用户" : "助手",
                                "content", message.getContent()
                        ));
                    } catch (IOException e) {
                        throw new UncheckedIOException(e);
                    }
                })
                .collect(Collectors.joining("\n"));
    }
}
