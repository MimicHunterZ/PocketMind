package com.doublez.pocketmindserver.ai.application.context;

import com.doublez.pocketmindserver.ai.application.memory.MemoryQueryService;
import com.doublez.pocketmindserver.ai.application.retrieval.AnalyzedIntent;
import com.doublez.pocketmindserver.ai.application.retrieval.ContextSnippet;
import com.doublez.pocketmindserver.ai.application.retrieval.IntentAnalyzer;
import com.doublez.pocketmindserver.ai.application.retrieval.OrchestratedContext;
import com.doublez.pocketmindserver.ai.application.retrieval.RetrievalOrchestrator;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionEntity;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionRepository;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import lombok.Builder;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;

@Slf4j
@Service
public class ContextDataRetriever {

    private final NoteRepository noteRepository;
    private final AttachmentVisionRepository attachmentVisionRepository;
    private final ResourceRecordRepository resourceRecordRepository;
    private final MemoryQueryService memoryQueryService;
    private final RetrievalOrchestrator retrievalOrchestrator;
    private final IntentAnalyzer intentAnalyzer;

    public ContextDataRetriever(
            NoteRepository noteRepository,
            AttachmentVisionRepository attachmentVisionRepository,
            ResourceRecordRepository resourceRecordRepository,
            MemoryQueryService memoryQueryService,
            RetrievalOrchestrator retrievalOrchestrator,
            IntentAnalyzer intentAnalyzer) {
        this.noteRepository = noteRepository;
        this.attachmentVisionRepository = attachmentVisionRepository;
        this.resourceRecordRepository = resourceRecordRepository;
        this.memoryQueryService = memoryQueryService;
        this.retrievalOrchestrator = retrievalOrchestrator;
        this.intentAnalyzer = intentAnalyzer;
    }

    public GlobalContextData retrieveGlobalContext(long userId, String userPrompt) {
        AnalyzedIntent intent = intentAnalyzer.analyze(userPrompt);
        List<ContextSnippet> memorySnippets = Collections.emptyList();
        List<ContextSnippet> resourceSnippets = Collections.emptyList();

        List<MemoryRecordEntity> userProfiles = memoryQueryService.queryMemoriesByType(userId, com.doublez.pocketmindserver.memory.domain.MemoryType.PROFILE, 100);
        List<MemoryRecordEntity> userPreferences = memoryQueryService.queryMemoriesByType(userId, com.doublez.pocketmindserver.memory.domain.MemoryType.PREFERENCES, 100);

        if (intent.needsRetrieval()) {
            OrchestratedContext ctx = retrievalOrchestrator.retrieve(userId, intent.queryText());
            if (ctx.memorySnippets() != null) {
                memorySnippets = ctx.memorySnippets();
            }
            if (ctx.resourceSnippets() != null) {
                resourceSnippets = ctx.resourceSnippets();
            }
        } else {
            log.debug("[context] 意图分析跳过全局检索: userId={}", userId);
        }

        return GlobalContextData.builder()
                .userProfiles(userProfiles)
                .userPreferences(userPreferences)
                .memorySnippets(memorySnippets)
                .resourceSnippets(resourceSnippets)
                .build();
    }

    public NoteScopedContextData retrieveNoteScopedContext(long userId, ChatSessionEntity session, String userPrompt) {
        UUID noteUuid = session.getScopeNoteUuid();
        
        List<MemoryRecordEntity> userProfiles = memoryQueryService.queryMemoriesByType(userId, com.doublez.pocketmindserver.memory.domain.MemoryType.PROFILE, 100);
        List<MemoryRecordEntity> userPreferences = memoryQueryService.queryMemoriesByType(userId, com.doublez.pocketmindserver.memory.domain.MemoryType.PREFERENCES, 100);

        List<MemoryRecordEntity> relevantMemories = memoryQueryService.queryRelevantMemories(userId, session, userPrompt);
        if (relevantMemories == null) {
            relevantMemories = Collections.emptyList();
        }

        List<ResourceRecordEntity> resources = resourceRecordRepository.findByNoteUuid(userId, noteUuid).stream()
                .filter(resource -> !resource.isDeleted())
                .sorted(Comparator.comparing(ResourceRecordEntity::getUpdatedAt).reversed())
                .toList();

        String noteTitle = null;
        String noteContent = null;

        Optional<ResourceRecordEntity> noteText = resources.stream()
                .filter(r -> r.getSourceType() == ResourceSourceType.NOTE_TEXT)
                .findFirst();

        if (noteText.isPresent()) {
            noteTitle = noteText.get().getTitle();
            noteContent = noteText.get().getContent();
        } else {
            NoteEntity note = noteRepository.findByUuidAndUserId(noteUuid, userId).orElse(null);
            if (note != null) {
                log.debug("[context] note={} 尚无 Resource 投影，回退到 Note 直读", noteUuid);
                noteTitle = note.getTitle();
                noteContent = hasText(note.getContent()) ? note.getContent() : note.getPreviewContent();
            }
        }

        String webSourceUrl = null;
        String webClipContent = null;
        Optional<ResourceRecordEntity> webClip = resources.stream()
                .filter(r -> r.getSourceType() == ResourceSourceType.WEB_CLIP)
                .findFirst();
        if (webClip.isPresent()) {
            webSourceUrl = webClip.get().getSourceUrl();
            webClipContent = webClip.get().getContent();
        }

        List<String> ocrTexts = attachmentVisionRepository.findDoneByNoteUuid(userId, noteUuid).stream()
                .map(AttachmentVisionEntity::getContent)
                .filter(Objects::nonNull)
                .filter(this::hasText)
                .toList();

        return NoteScopedContextData.builder()
                .relevantMemories(relevantMemories)
                .noteTitle(noteTitle)
                .noteContent(noteContent)
                .webSourceUrl(webSourceUrl)
                .webClipContent(webClipContent)
                .ocrTexts(ocrTexts)
                .build();
    }

    private boolean hasText(String text) {
        return text != null && !text.trim().isEmpty();
    }

    @Data
    @Builder
    public static class GlobalContextData {
        private List<MemoryRecordEntity> userProfiles;
        private List<MemoryRecordEntity> userPreferences;
        private List<ContextSnippet> memorySnippets;
        private List<ContextSnippet> resourceSnippets;
    }

    @Data
    @Builder
    public static class NoteScopedContextData {
        private List<MemoryRecordEntity> userProfiles;
        private List<MemoryRecordEntity> userPreferences;
        private List<MemoryRecordEntity> relevantMemories;
        private String noteTitle;
        private String noteContent;
        private String webSourceUrl;
        private String webClipContent;
        private List<String> ocrTexts;
    }
}
