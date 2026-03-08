package com.doublez.pocketmindserver.ai.application.context;

import com.doublez.pocketmindserver.ai.application.memory.MemoryQueryService;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionEntity;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionRepository;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

/**
 * 聊天上下文装配器。
 *
 * 负责从 Resource / Note / OCR / Memory 组装聊天所需上下文，避免由聊天服务直接拼字段。
 */
@Slf4j
@Service
public class ContextAssembler {

    private final NoteRepository noteRepository;
    private final AttachmentVisionRepository attachmentVisionRepository;
    private final ResourceRecordRepository resourceRecordRepository;
    private final MemoryQueryService memoryQueryService;

    @Value("classpath:prompts/chat/global_system.md")
    private Resource globalSystemTemplate;

    @Value("classpath:prompts/chat/note_system.md")
    private Resource noteSystemTemplate;

    @Value("classpath:prompts/chat/context/system_with_extra_section.md")
    private Resource systemWithExtraSectionTemplate;

    @Value("classpath:prompts/chat/context/note_context.md")
    private Resource noteContextTemplate;

    @Value("classpath:prompts/chat/context/note_text_section.md")
    private Resource noteTextSectionTemplate;

    @Value("classpath:prompts/chat/context/web_clip_section.md")
    private Resource webClipSectionTemplate;

    @Value("classpath:prompts/chat/context/ocr_section.md")
    private Resource ocrSectionTemplate;

    @Value("classpath:prompts/chat/context/memory_section.md")
    private Resource memorySectionTemplate;

    public ContextAssembler(NoteRepository noteRepository,
                            AttachmentVisionRepository attachmentVisionRepository,
                            ResourceRecordRepository resourceRecordRepository,
                            MemoryQueryService memoryQueryService) {
        this.noteRepository = noteRepository;
        this.attachmentVisionRepository = attachmentVisionRepository;
        this.resourceRecordRepository = resourceRecordRepository;
        this.memoryQueryService = memoryQueryService;
    }

    /**
     * 组装 system prompt。
     */
    public String buildSystemPrompt(long userId, ChatSessionEntity session, String userPrompt) {
        try {
            String memoryContext = memoryQueryService.buildMemoryContext(userId, session, userPrompt);
            String memorySection = renderMemorySection(memoryContext);
            if (session.getScopeNoteUuid() == null) {
                return renderGlobalPrompt(memorySection);
            }

            String noteContext = buildNoteContext(userId, session.getScopeNoteUuid(), memorySection);
            if (!hasText(noteContext)) {
                return renderGlobalPrompt(memorySection);
            }

            return PromptBuilder.render(
                    noteSystemTemplate,
                    Map.of("noteContext", noteContext)
            );
        } catch (IOException e) {
            throw new UncheckedIOException("加载对话系统提示词模板失败", e);
        }
    }

    private String renderGlobalPrompt(String memorySection) throws IOException {
        String systemText = globalSystemTemplate.getContentAsString(StandardCharsets.UTF_8);
        if (!hasText(memorySection)) {
            return systemText;
        }
        return PromptBuilder.render(
                systemWithExtraSectionTemplate,
                Map.of(
                        "systemText", systemText,
                        "extraSection", memorySection
                )
        );
    }

    private String buildNoteContext(long userId, UUID noteUuid, String memorySection) throws IOException {
        List<ResourceRecordEntity> resources = resourceRecordRepository.findByNoteUuid(userId, noteUuid).stream()
                .filter(resource -> !resource.isDeleted())
                .sorted(Comparator.comparing(ResourceRecordEntity::getUpdatedAt).reversed())
                .toList();

        String noteTextSection = buildNoteTextSection(userId, noteUuid, resources);
        String webClipSection = buildWebClipSection(resources);
        String ocrSection = buildOcrSection(userId, noteUuid);

        return PromptBuilder.render(
                noteContextTemplate,
                Map.of(
                        "noteTextSection", noteTextSection,
                        "webClipSection", webClipSection,
                        "ocrSection", ocrSection,
                        "memorySection", memorySection
                )
        ).trim();
    }

    private String buildNoteTextSection(long userId,
                                        UUID noteUuid,
                                        List<ResourceRecordEntity> resources) throws IOException {
        Optional<ResourceRecordEntity> noteText = resources.stream()
                .filter(resource -> resource.getSourceType() == ResourceSourceType.NOTE_TEXT)
                .findFirst();

        if (noteText.isPresent()) {
            return renderNoteTextSection(noteText.get().getTitle(), noteText.get().getContent());
        }

        NoteEntity note = noteRepository.findByUuidAndUserId(noteUuid, userId).orElse(null);
        if (note == null) {
            return "";
        }

        log.debug("[context] note={} 尚无 Resource 投影，回退到 Note 直读", noteUuid);
        String bodyContent = hasText(note.getContent()) ? note.getContent() : note.getPreviewContent();
        return renderNoteTextSection(note.getTitle(), bodyContent);
    }

    private String renderNoteTextSection(String title, String content) throws IOException {
        if (!hasText(title) && !hasText(content)) {
            return "";
        }
        return PromptBuilder.render(
                noteTextSectionTemplate,
                Map.of(
                        "title", safeText(title),
                        "content", safeText(content)
                )
        );
    }

    private String buildWebClipSection(List<ResourceRecordEntity> resources) throws IOException {
        Optional<ResourceRecordEntity> webClip = resources.stream()
                .filter(resource -> resource.getSourceType() == ResourceSourceType.WEB_CLIP)
                .findFirst();
        if (webClip.isEmpty()) {
            return "";
        }

        ResourceRecordEntity resource = webClip.get();
        return PromptBuilder.render(
                webClipSectionTemplate,
                Map.of(
                        "title", safeText(resource.getTitle()),
                        "sourceUrl", safeText(resource.getSourceUrl()),
                        "content", safeText(resource.getContent())
                )
        );
    }

    private String buildOcrSection(long userId, UUID noteUuid) throws IOException {
        List<String> imageTexts = attachmentVisionRepository.findDoneByNoteUuid(userId, noteUuid).stream()
                .map(AttachmentVisionEntity::getContent)
                .filter(Objects::nonNull)
                .filter(this::hasText)
                .toList();
        if (imageTexts.isEmpty()) {
            return "";
        }
        return PromptBuilder.render(
                ocrSectionTemplate,
                Map.of("imageTexts", imageTexts)
        );
    }

    private String renderMemorySection(String memoryContext) throws IOException {
        if (!hasText(memoryContext)) {
            return "";
        }
        return PromptBuilder.render(
                memorySectionTemplate,
                Map.of("memoryContext", memoryContext)
        );
    }

    private String safeText(String text) {
        return text == null ? "" : text;
    }

    private boolean hasText(String text) {
        return text != null && !text.isBlank();
    }
}
