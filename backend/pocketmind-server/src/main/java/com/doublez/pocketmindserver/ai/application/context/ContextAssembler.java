package com.doublez.pocketmindserver.ai.application.context;

import com.doublez.pocketmindserver.ai.application.memory.MemoryInjector;
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
import java.util.stream.Collectors;

/**
 * 聊天上下文装配器。
 *
 * <p>负责从 Resource / Note / OCR / Memory 组装聊天所需上下文，避免由聊天服务直接拼字段。
 *
 * <p>全局对话走 {@link RetrievalOrchestrator} 双通道检索（Resource + Memory），
 * 由 {@link IntentAnalyzer} 决定是否需要资源检索。
 * 笔记对话保持直接加载绑定笔记的 Resource，记忆由 {@link MemoryQueryService} 提供。
 */
@Slf4j
@Service
public class ContextAssembler {

    private final NoteRepository noteRepository;
    private final AttachmentVisionRepository attachmentVisionRepository;
    private final ResourceRecordRepository resourceRecordRepository;
    private final MemoryQueryService memoryQueryService;
    private final MemoryInjector memoryInjector;
    private final RetrievalOrchestrator retrievalOrchestrator;
    private final IntentAnalyzer intentAnalyzer;

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

    /** 检索到的资料片段外层包裹模板 */
    @Value("classpath:prompts/chat/context/resource_snippets_section.md")
    private Resource resourceSnippetsSectionTemplate;

    /** 单条资料片段渲染模板 */
    @Value("classpath:prompts/chat/context/resource_snippet_item.md")
    private Resource resourceSnippetItemTemplate;

    public ContextAssembler(NoteRepository noteRepository,
                            AttachmentVisionRepository attachmentVisionRepository,
                            ResourceRecordRepository resourceRecordRepository,
                            MemoryQueryService memoryQueryService,
                            MemoryInjector memoryInjector,
                            RetrievalOrchestrator retrievalOrchestrator,
                            IntentAnalyzer intentAnalyzer) {
        this.noteRepository = noteRepository;
        this.attachmentVisionRepository = attachmentVisionRepository;
        this.resourceRecordRepository = resourceRecordRepository;
        this.memoryQueryService = memoryQueryService;
        this.memoryInjector = memoryInjector;
        this.retrievalOrchestrator = retrievalOrchestrator;
        this.intentAnalyzer = intentAnalyzer;
    }

    /**
     * 组装 system prompt。
     *
     * <p>全局对话走双通道检索；笔记对话保持直接加载。
     */
    public String buildSystemPrompt(long userId, ChatSessionEntity session, String userPrompt) {
        try {
            // 笔记对话：直接加载绑定笔记的 Resource + 记忆
            if (session.getScopeNoteUuid() != null) {
                return buildNoteScopedPrompt(userId, session, userPrompt);
            }
            // 全局对话：走 RetrievalOrchestrator 双通道检索
            return buildGlobalPrompt(userId, session, userPrompt);
        } catch (IOException e) {
            throw new UncheckedIOException("加载对话系统提示词模板失败", e);
        }
    }

    /**
     * 全局对话：IntentAnalyzer 分析 → RetrievalOrchestrator 双通道检索 → 组装。
     */
    private String buildGlobalPrompt(long userId, ChatSessionEntity session, String userPrompt) throws IOException {
        AnalyzedIntent intent = intentAnalyzer.analyze(userPrompt);
        String systemText = globalSystemTemplate.getContentAsString(StandardCharsets.UTF_8);

        if (!intent.needsRetrieval()) {
            log.debug("[context] 意图分析跳过检索: userId={}", userId);
            return systemText;
        }

        // 双通道并行检索
        OrchestratedContext ctx = retrievalOrchestrator.retrieve(userId, intent.queryText());
        List<MemoryRecordEntity> allMemories = memoryInjector.queryAllMemories(userId);
        String memorySection = renderMemorySection(ctx.memorySnippets(), allMemories);
        if (ctx.isEmpty()) {
            if (!hasText(memorySection)) {
                return systemText;
            }
            return PromptBuilder.render(
                    systemWithExtraSectionTemplate,
                    Map.of("systemText", systemText, "extraSection", memorySection)
            );
        }

        // 分别渲染 Memory 和 Resource 片段为文本段落
        String resourceSection = renderResourceSnippetsSection(ctx.resourceSnippets());

        // 合并为 extraSection 注入系统提示
        String extraSection = joinSections(memorySection, resourceSection);
        if (!hasText(extraSection)) {
            return systemText;
        }
        return PromptBuilder.render(
                systemWithExtraSectionTemplate,
                Map.of("systemText", systemText, "extraSection", extraSection)
        );
    }

    /**
     * 笔记对话：直接加载绑定 Note 的 Resource + OCR，搭配 MemoryQueryService 查记忆。
     */
    private String buildNoteScopedPrompt(long userId, ChatSessionEntity session, String userPrompt) throws IOException {
        List<MemoryRecordEntity> relevantMemories = memoryQueryService.queryRelevantMemories(userId, session, userPrompt);
        List<MemoryRecordEntity> allMemories = memoryInjector.queryAllMemories(userId);
        String memorySection = renderMemorySection(relevantMemories, allMemories);

        String noteContext = buildNoteContext(userId, session.getScopeNoteUuid(), memorySection);
        if (!hasText(noteContext)) {
            return renderFallbackGlobalPrompt(memorySection);
        }
        return PromptBuilder.render(
                noteSystemTemplate,
                Map.of("noteContext", noteContext)
        );
    }

    /**
     * 兜底：笔记对话找不到笔记时，降级为全局 + 已检索的记忆。
     */
    private String renderFallbackGlobalPrompt(String memorySection) throws IOException {
        String systemText = globalSystemTemplate.getContentAsString(StandardCharsets.UTF_8);
        if (!hasText(memorySection)) {
            return systemText;
        }
        return PromptBuilder.render(
                systemWithExtraSectionTemplate,
                Map.of("systemText", systemText, "extraSection", memorySection)
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

        private String renderMemorySection(List<MemoryRecordEntity> relevantMemories,
                           List<MemoryRecordEntity> allMemories) throws IOException {
        String hitItems = toMemoryHitItems(relevantMemories);
        String allItems = toMemoryAllItems(allMemories);
        if (!hasText(hitItems) && !hasText(allItems)) {
            return "";
        }
        return PromptBuilder.render(
                memorySectionTemplate,
            Map.of(
                "hitCount", String.valueOf(relevantMemories == null ? 0 : relevantMemories.size()),
                "allCount", String.valueOf(allMemories == null ? 0 : allMemories.size()),
                "hitItems", hitItems,
                "allItems", allItems
            )
        );
    }

    /**
         * 全局检索场景：使用检索片段 + 全量记忆渲染记忆段落。
     */
        private String renderMemorySection(List<ContextSnippet> memorySnippets,
                           List<MemoryRecordEntity> allMemories) throws IOException {
        String hitItems = toMemoryHitItemsFromSnippets(memorySnippets);
        String allItems = toMemoryAllItems(allMemories);
        if (!hasText(hitItems) && !hasText(allItems)) {
            return "";
        }
        return PromptBuilder.render(
                memorySectionTemplate,
            Map.of(
                "hitCount", String.valueOf(memorySnippets == null ? 0 : memorySnippets.size()),
                "allCount", String.valueOf(allMemories == null ? 0 : allMemories.size()),
                "hitItems", hitItems,
                "allItems", allItems
            )
        );
    }

        private String toMemoryHitItems(List<MemoryRecordEntity> memories) {
        if (memories == null || memories.isEmpty()) {
            return "";
        }
        return memories.stream()
            .map(m -> "- [" + m.getMemoryType().name() + "] " + safeText(m.getTitle())
                + "\n  摘要：" + safeText(m.getAbstractText())
                + (hasText(m.getContent()) ? "\n  内容：" + m.getContent() : ""))
            .collect(Collectors.joining("\n"));
        }

        private String toMemoryHitItemsFromSnippets(List<ContextSnippet> snippets) {
        if (snippets == null || snippets.isEmpty()) {
            return "";
        }
        return snippets.stream()
            .map(s -> "- [MEMORY] " + safeText(s.title())
                + "\n  摘要：" + safeText(s.abstractText())
                + (hasText(s.content()) ? "\n  内容：" + s.content() : ""))
            .collect(Collectors.joining("\n"));
        }

        private String toMemoryAllItems(List<MemoryRecordEntity> memories) {
        if (memories == null || memories.isEmpty()) {
            return "";
        }
        return memories.stream()
            .map(m -> "- [" + m.getMemoryType().name() + "] " + safeText(m.getTitle())
                + "\n  摘要：" + safeText(m.getAbstractText()))
            .collect(Collectors.joining("\n"));
        }

    /**
     * 渲染检索到的 Resource 片段为可注入系统提示的段落。
     */
    private String renderResourceSnippetsSection(List<ContextSnippet> resourceSnippets) throws IOException {
        if (resourceSnippets == null || resourceSnippets.isEmpty()) {
            return "";
        }
        String items = resourceSnippets.stream()
                .map(s -> {
                    try {
                        return PromptBuilder.render(resourceSnippetItemTemplate, Map.of(
                                "title", safeText(s.title()),
                                "abstractText", safeText(s.abstractText())
                        ));
                    } catch (IOException e) {
                        throw new UncheckedIOException(e);
                    }
                })
                .collect(Collectors.joining("\n"));
        return PromptBuilder.render(
                resourceSnippetsSectionTemplate,
                Map.of("snippets", items)
        );
    }

    /**
     * 合并多个段落文本（跳过空白段落）。
     */
    private String joinSections(String... sections) {
        StringBuilder sb = new StringBuilder();
        for (String section : sections) {
            if (hasText(section)) {
                if (!sb.isEmpty()) {
                    sb.append("\n\n");
                }
                sb.append(section);
            }
        }
        return sb.toString();
    }

    private String safeText(String text) {
        return text == null ? "" : text;
    }

    private boolean hasText(String text) {
        return text != null && !text.isBlank();
    }
}
