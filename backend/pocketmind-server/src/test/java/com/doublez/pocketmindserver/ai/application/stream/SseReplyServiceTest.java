package com.doublez.pocketmindserver.ai.application.stream;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.ai.tool.skill.TenantSkillToolResolver;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.memory.application.MemoryToolSet;
import com.doublez.pocketmindserver.resource.application.ChatTranscriptResourceSyncService;
import com.doublez.pocketmindserver.resource.application.tool.ResourceToolSet;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

/**
 * SseReplyService 行为测试。
 */
@ExtendWith(MockitoExtension.class)
class SseReplyServiceTest {

    @Mock
    private AiFailoverRouter aiFailoverRouter;
    @Mock
    private ChatMessageRepository chatMessageRepository;
    @Mock
    private TenantSkillToolResolver tenantSkillToolResolver;
    @Mock
    private ChatTranscriptResourceSyncService chatTranscriptResourceSyncService;
    @Mock
    private MemoryToolSet.MemoryToolSetFactory memoryToolSetFactory;
    @Mock
    private ResourceToolSet.ResourceToolSetFactory resourceToolSetFactory;

    @Test
    void persistAssistantShouldNotTriggerTranscriptSyncDirectly() {
        SseReplyService service = new SseReplyService(
                aiFailoverRouter,
                chatMessageRepository,
                new ChatStreamCancellationManager(),
                new ChatSseEventFactory(new com.fasterxml.jackson.databind.ObjectMapper()),
                tenantSkillToolResolver,
                chatTranscriptResourceSyncService,
                memoryToolSetFactory,
                null,
                resourceToolSetFactory
        );

        UUID result = ReflectionTestUtils.invokeMethod(
                service,
                "persistAssistant",
                100L,
                UUID.randomUUID(),
                UUID.randomUUID(),
                "assistant content"
        );

        assertNotNull(result);
        verify(chatMessageRepository).save(org.mockito.ArgumentMatchers.any());
        verify(chatTranscriptResourceSyncService, never()).syncSessionTranscript(org.mockito.ArgumentMatchers.anyLong(), org.mockito.ArgumentMatchers.any());
    }
}
