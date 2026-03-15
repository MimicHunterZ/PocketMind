package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.api.dto.AiAnalyseAcceptRequest;
import com.doublez.pocketmindserver.sync.event.NoteAiPipelineEvent;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import java.util.Optional;

/**
 * 笔记 AI 管线监听器。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NoteAiPipelineEventListener {

    private final NoteRepository noteRepository;
    private final AiAnalysePollingService aiAnalysePollingService;

    @Async
    @EventListener
    public void handleNoteAiPipelineEvent(NoteAiPipelineEvent event) {
        log.info("接收到 NoteAiPipelineEvent，开始处理: noteUuid={}, userId={}", event.noteUuid(), event.userId());
        Optional<NoteEntity> optNote = noteRepository.findByUuidAndUserId(event.noteUuid(), event.userId());
        if (optNote.isEmpty()) {
            log.warn("处理 NoteAiPipelineEvent 时未找到笔记: noteUuid={}", event.noteUuid());
            return;
        }
        
        NoteEntity note = optNote.get();
        if (note.getSourceUrl() == null || note.getSourceUrl().isBlank()) {
            log.info("笔记不含 URL，跳过分析: noteUuid={}", event.noteUuid());
            return;
        }

        try {
            // 提交给 AI 分析管线处理
            AiAnalyseAcceptRequest request = new AiAnalyseAcceptRequest(
                event.noteUuid(),
                note.getSourceUrl(),
                note.getPreviewTitle(),
                note.getPreviewDescription(),
                note.getPreviewContent(),
                null,
                note.getTitle(),
                note.getContent()
            );
            aiAnalysePollingService.accept(String.valueOf(event.userId()), request);
            log.info("已提交笔记到 AI 分析管线: noteUuid={}", event.noteUuid());
        } catch (Exception e) {
            log.error("处理 NoteAiPipelineEvent 异常: noteUuid={}", event.noteUuid(), e);
        }
    }
}
