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
import com.doublez.pocketmindserver.user.application.UserSettingService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 聊天上下文装配器。
 * <p>负责从 Resource / Note / OCR / Memory 以及 UserSettings 组装聊天所需上下文。</p>
 */
@Slf4j
@Service
public class ContextAssembler {

    private static final int MAX_UNTRUSTED_TEXT_CHARS = 4000;

    private final NoteRepository noteRepository;
    private final AttachmentVisionRepository attachmentVisionRepository;
    private final ResourceRecordRepository resourceRecordRepository;
    private final MemoryQueryService memoryQueryService;
    private final MemoryInjector memoryInjector;
    private final RetrievalOrchestrator retrievalOrchestrator;
    private final IntentAnalyzer intentAnalyzer;
    private final UserSettingService userSettingService;

    @Value("classpath:prompts/chat/global_system.md")
    private Resource globalSystemTemplate;

    @Value("classpath:prompts/chat/note_system.md")
    private Resource noteSystemTemplate;

    @Value("classpath:prompts/chat/note_section.md")
    private Resource noteSectionTemplate;

    @Value("classpath:prompts/chat/persona/global_default.md")
    private Resource defaultGlobalPersonaTemplate;

    @Value("classpath:prompts/chat/persona/note_default.md")
    private Resource defaultNotePersonaTemplate;

    @Value("classpath:prompts/chat/persona/superpowers_fallback.st")
    private Resource superpowersFallbackTemplate;

    @Value("classpath:prompts/chat/context/memory_l0_item.md")
    private Resource memoryL0ItemTemplate;

    @Value("classpath:prompts/chat/context/resource_snippet_item.md")
    private Resource resourceSnippetItemTemplate;

    public ContextAssembler(NoteRepository noteRepository,
                            AttachmentVisionRepository attachmentVisionRepository,
                            ResourceRecordRepository resourceRecordRepository,
                            MemoryQueryService memoryQueryService,
                            MemoryInjector memoryInjector,
                            RetrievalOrchestrator retrievalOrchestrator,
                            IntentAnalyzer intentAnalyzer,
                            UserSettingService userSettingService) {
        this.noteRepository = noteRepository;
        this.attachmentVisionRepository = attachmentVisionRepository;
        this.resourceRecordRepository = resourceRecordRepository;
        this.memoryQueryService = memoryQueryService;
        this.memoryInjector = memoryInjector;
        this.retrievalOrchestrator = retrievalOrchestrator;
        this.intentAnalyzer = intentAnalyzer;
        this.userSettingService = userSettingService;
    }

    /**
     * 组装 system prompt。
     */
    public String buildSystemPrompt(long userId, ChatSessionEntity session, String userPrompt) {
        try {
            if (session.getScopeNoteUuid() != null) {
                return buildNoteScopedPrompt(userId, session, userPrompt);
            }
            return buildGlobalPrompt(userId, session, userPrompt);
        } catch (IOException e) {
            throw new UncheckedIOException("加载对话系统提示词模板失败", e);
        }
    }

    private String buildGlobalPrompt(long userId, ChatSessionEntity session, String userPrompt) throws IOException {
        AnalyzedIntent intent = intentAnalyzer.analyze(userPrompt);
        Map<String, Object> variables = new HashMap<>();
        variables.put("persona", resolvePersona(userId, defaultGlobalPersonaTemplate));

        // 2. 意图分析与全系统检索
        List<ContextSnippet> memorySnippets = Collections.emptyList();
        List<ContextSnippet> resourceSnippets = Collections.emptyList();

        if (intent.needsRetrieval()) {
            OrchestratedContext ctx = retrievalOrchestrator.retrieve(userId, intent.queryText());
            memorySnippets = ctx.memorySnippets() != null ? ctx.memorySnippets() : Collections.emptyList();
            resourceSnippets = ctx.resourceSnippets() != null ? ctx.resourceSnippets() : Collections.emptyList();
            
            if (!resourceSnippets.isEmpty()) {
                variables.put("resources", renderResourceSnippets(resourceSnippets));
            }
        } else {
            log.debug("[context] 意图分析跳过检索: userId={}", userId);
        }

        // 3. 记忆合并与去重 (命中记忆 + 全量记忆) -> 形成单一 L0 展示
        List<MemoryRecordEntity> allMemories = memoryInjector.queryAllMemories(userId);
        String deduplicatedMemories = mergeAndFormatL0Memories(memorySnippets, allMemories);
        if (hasText(deduplicatedMemories)) {
            variables.put("memories", deduplicatedMemories);
        }

        return PromptBuilder.render(globalSystemTemplate, variables);
    }

    private String buildNoteScopedPrompt(long userId, ChatSessionEntity session, String userPrompt) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("persona", resolvePersona(userId, defaultNotePersonaTemplate));

        // 2. 相关记忆 (命中记忆 + 全量记忆去重)
        List<MemoryRecordEntity> relevantMemories = memoryQueryService.queryRelevantMemories(userId, session, userPrompt);
        List<MemoryRecordEntity> allMemories = memoryInjector.queryAllMemories(userId);
        
        Set<UUID> seenUuids = new HashSet<>();
        List<String> combinedMemories = new ArrayList<>();
        
        if (relevantMemories != null) {
            for (MemoryRecordEntity m : relevantMemories) {
                if (seenUuids.add(m.getUuid())) {
                    combinedMemories.add(formatMemoryL0(m, ""));
                }
            }
        }
        if (allMemories != null) {
            for (MemoryRecordEntity m : allMemories) {
                if (seenUuids.add(m.getUuid())) {
                    combinedMemories.add(formatMemoryL0(m, ""));
                }
            }
        }
        
        if (!combinedMemories.isEmpty()) {
            variables.put("memories", String.join("\n", combinedMemories));
        }

        // 3. 填充核心笔记上下文
        UUID noteUuid = session.getScopeNoteUuid();
        List<ResourceRecordEntity> resources = resourceRecordRepository.findByNoteUuid(userId, noteUuid).stream()
                .filter(resource -> !resource.isDeleted())
                .sorted(Comparator.comparing(ResourceRecordEntity::getUpdatedAt).reversed())
                .toList();

        // 3.1 Note Text
        Optional<ResourceRecordEntity> noteText = resources.stream()
                .filter(r -> r.getSourceType() == ResourceSourceType.NOTE_TEXT)
                .findFirst();
        
        if (noteText.isPresent()) {
            variables.put("noteTitle", safeText(noteText.get().getTitle()));
            if (hasText(noteText.get().getContent())) {
                variables.put("noteContent", sanitizeUntrustedText(noteText.get().getContent()));
            }
        } else {
            NoteEntity note = noteRepository.findByUuidAndUserId(noteUuid, userId).orElse(null);
            if (note != null) {
                log.debug("[context] note={} 尚无 Resource 投影，回退到 Note 直读", noteUuid);
                variables.put("noteTitle", safeText(note.getTitle()));
                String bodyContent = hasText(note.getContent()) ? note.getContent() : note.getPreviewContent();
                if (hasText(bodyContent)) {
                    variables.put("noteContent", sanitizeUntrustedText(bodyContent));
                }
            }
        }

        // 3.2 Web Clip
        resources.stream()
                .filter(r -> r.getSourceType() == ResourceSourceType.WEB_CLIP)
                .findFirst()
                .ifPresent(clip -> {
                    variables.put("webSourceUrl", sanitizeUrl(clip.getSourceUrl()));
                    variables.put("webClipContent", sanitizeUntrustedText(clip.getContent()));
                });

        // 3.3 OCR Texts
        List<String> imageTexts = attachmentVisionRepository.findDoneByNoteUuid(userId, noteUuid).stream()
                .map(AttachmentVisionEntity::getContent)
                .filter(Objects::nonNull)
                .filter(this::hasText)
                .map(this::sanitizeUntrustedText)
                .toList();
        if (!imageTexts.isEmpty()) {
            variables.put("ocrTexts", "- " + String.join("\n- ", imageTexts));
        }

        // 如果笔记被删了完全没有元数据，走兜底全局模板
        if (!variables.containsKey("noteTitle") && !variables.containsKey("noteContent")) {
            return PromptBuilder.render(globalSystemTemplate, variables);
        }

        variables.put("noteSection", renderNoteSection(variables));

        return PromptBuilder.render(noteSystemTemplate, variables);
    }

    private String resolvePersona(long userId, Resource defaultPersonaResource) {
        String activePrompt = userSettingService.getActivePersonaPrompt(userId);
        if (hasText(activePrompt)) {
            return activePrompt.trim();
        }
        return readTemplateOrEmpty(superpowersFallbackTemplate);
    }

    private String renderNoteSection(Map<String, Object> sourceVariables) throws IOException {
        if (noteSectionTemplate == null) {
            return "";
        }
        Map<String, Object> noteVariables = new HashMap<>();
        copyIfPresent(sourceVariables, noteVariables, "noteTitle");
        copyIfPresent(sourceVariables, noteVariables, "noteContent");
        copyIfPresent(sourceVariables, noteVariables, "webSourceUrl");
        copyIfPresent(sourceVariables, noteVariables, "webClipContent");
        copyIfPresent(sourceVariables, noteVariables, "ocrTexts");
        return PromptBuilder.render(noteSectionTemplate, noteVariables);
    }

    private void copyIfPresent(Map<String, Object> source, Map<String, Object> target, String key) {
        if (source.containsKey(key)) {
            target.put(key, source.get(key));
        }
    }

    private String readTemplateOrEmpty(Resource template) {
        if (template == null) {
            return "";
        }
        try {
            return template.getContentAsString(StandardCharsets.UTF_8).trim();
        } catch (IOException e) {
            log.warn("[context] 读取默认人设模板失败: {}", template, e);
            return "";
        }
    }

    /**
     * 将通过Snippet检索到的记忆和全量记忆合并去重，转为单行 L0 显示
     */
    private String mergeAndFormatL0Memories(List<ContextSnippet> snippets, List<MemoryRecordEntity> allMemories) throws IOException {
        Set<String> seenIds = new HashSet<>();
        List<String> combined = new ArrayList<>();

        if (snippets != null) {
            for (ContextSnippet s : snippets) {
                // Snippet 的 ID 形如 pm://memories/<uuid>
                String rawId = safeText(s.uri()).replace("pm://memories/", "");
                if (seenIds.add(rawId)) {
                    combined.add(PromptBuilder.render(memoryL0ItemTemplate, Map.of(
                            "id", rawId,
                            "memoryType", "Hit",
                            "title", safeText(s.title()),
                            "abstractText", safeText(s.abstractText())
                    )));
                }
            }
        }

        if (allMemories != null) {
            for (MemoryRecordEntity m : allMemories) {
                String id = m.getUuid().toString();
                if (seenIds.add(id)) {
                    combined.add(formatMemoryL0(m, id));
                }
            }
        }

        if (combined.isEmpty()) {
            return "";
        }
        return String.join("\n", combined);
    }

    private String formatMemoryL0(MemoryRecordEntity m, String id) throws IOException {
        String memoryId = hasText(id) ? id : m.getUuid().toString();
        return PromptBuilder.render(memoryL0ItemTemplate, Map.of(
                "id", memoryId,
                "memoryType", m.getMemoryType().name(),
                "title", safeText(m.getTitle()),
                "abstractText", safeText(m.getAbstractText())
        ));
    }

    private String renderResourceSnippets(List<ContextSnippet> resourceSnippets) throws IOException {
        if (resourceSnippets == null || resourceSnippets.isEmpty()) {
            return "";
        }
        return resourceSnippets.stream()
                .map(s -> {
                    try {
                        return PromptBuilder.render(resourceSnippetItemTemplate, Map.of(
                                "title", safeText(s.title()),
                                "uri", safeText(s.uri()),
                                "abstractText", safeText(s.abstractText())
                        ));
                    } catch (IOException e) {
                        throw new UncheckedIOException(e);
                    }
                })
                .collect(Collectors.joining("\n\n"));
    }

    private String safeText(String text) {
        return text == null ? "" : text;
    }

    private String sanitizeUntrustedText(String text) {
        if (!hasText(text)) {
            return "";
        }
        String normalized = text
                .replace("\r\n", "\n")
                .replace("\r", "\n")
                // 防御 markdown 本身的闭合逃逸风险
                .replace("```", "` ` `")
                .trim();
        if (normalized.length() <= MAX_UNTRUSTED_TEXT_CHARS) {
            return normalized;
        }
        return normalized.substring(0, MAX_UNTRUSTED_TEXT_CHARS) + "\n...(内容已截断)";
    }

    private String sanitizeUrl(String sourceUrl) {
        String sanitized = safeText(sourceUrl).trim();
        if (sanitized.startsWith("https://") || sanitized.startsWith("http://")) {
            return sanitized;
        }
        return "";
    }

    private boolean hasText(String text) {
        return text != null && !text.isBlank();
    }
}
