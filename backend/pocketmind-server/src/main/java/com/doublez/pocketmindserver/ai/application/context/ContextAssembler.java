package com.doublez.pocketmindserver.ai.application.context;

import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.ai.application.retrieval.ContextSnippet;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import com.doublez.pocketmindserver.user.application.UserSettingService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 聊天上下文装配器。
 * <p>负责将检索到的数据格式化为 Prompt，将变量安全替换后发送给大模型。</p>
 */
@Slf4j
@Service
public class ContextAssembler {

    private final ContextDataRetriever contextDataRetriever;
    private final UserSettingService userSettingService;

    @Value("classpath:prompts/chat/global_system.md")
    private Resource globalSystemTemplate;

    @Value("classpath:prompts/chat/note_system.md")
    private Resource noteSystemTemplate;

    public ContextAssembler(
            ContextDataRetriever contextDataRetriever,
            UserSettingService userSettingService) {
        this.contextDataRetriever = contextDataRetriever;
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
        ContextDataRetriever.GlobalContextData data = contextDataRetriever.retrieveGlobalContext(userId, userPrompt);

        Map<String, Object> variables = initVariables();

        String activePersona = userSettingService.getActivePersonaPrompt(userId);
        variables.put("persona", nullableText(activePersona));

        variables.put("profilesBlock", joinLines(extractMemoryContents(data.getUserProfiles())));
        variables.put("preferencesBlock", joinLines(extractMemoryContents(data.getUserPreferences())));
        variables.put("relevantMemoriesBlock", joinLines(extractRelevantMemoryLines(
            data.getMemorySnippets(), Collections.emptyList())));
        variables.put("resourcesBlock", joinLines(extractResourceLines(data.getResourceSnippets())));

        return PromptBuilder.render(globalSystemTemplate, variables);
    }

    private String buildNoteScopedPrompt(long userId, ChatSessionEntity session, String userPrompt) throws IOException {
        ContextDataRetriever.NoteScopedContextData data = contextDataRetriever.retrieveNoteScopedContext(userId, session, userPrompt);

        Map<String, Object> variables = initVariables();

        String activePersona = userSettingService.getActivePersonaPrompt(userId);
        variables.put("persona", nullableText(activePersona));

        variables.put("profilesBlock", joinLines(extractMemoryContents(data.getUserProfiles())));
        variables.put("preferencesBlock", joinLines(extractMemoryContents(data.getUserPreferences())));
        variables.put("relevantMemoriesBlock", joinLines(extractRelevantMemoryLines(
            Collections.emptyList(), data.getRelevantMemories())));

        variables.put("noteTitle", safeText(data.getNoteTitle()));
        variables.put("noteContent", safeText(data.getNoteContent()));
        variables.put("webSourceUrl", safeText(data.getWebSourceUrl()));
        variables.put("webClipContent", safeText(data.getWebClipContent()));
        variables.put("ocrTextsBlock", joinLines(defaultList(data.getOcrTexts())));

        boolean hasNoteData = hasText(data.getNoteTitle()) || hasText(data.getNoteContent());
        
        if (!hasNoteData) {
            variables.put("resourcesBlock", "");
            return PromptBuilder.render(globalSystemTemplate, variables);
        }

        return PromptBuilder.render(noteSystemTemplate, variables);
    }

    private Map<String, Object> initVariables() {
        Map<String, Object> variables = new HashMap<>();
        variables.put("persona", null);
        variables.put("profilesBlock", "");
        variables.put("preferencesBlock", "");
        variables.put("relevantMemoriesBlock", "");
        variables.put("resourcesBlock", "");
        variables.put("noteTitle", "");
        variables.put("noteContent", "");
        variables.put("webSourceUrl", "");
        variables.put("webClipContent", "");
        variables.put("ocrTextsBlock", "");
        return variables;
    }

    private List<String> extractMemoryContents(List<MemoryRecordEntity> memories) {
        if (memories == null || memories.isEmpty()) {
            return Collections.emptyList();
        }
        List<String> items = new ArrayList<>();
        for (MemoryRecordEntity memory : memories) {
            String content = hasText(memory.getContent()) ? memory.getContent() : memory.getAbstractText();
            if (hasText(content)) {
                items.add(content.trim());
            }
        }
        return items;
    }

    private List<String> extractRelevantMemoryLines(List<ContextSnippet> snippets, List<MemoryRecordEntity> memories) {
        List<String> items = new ArrayList<>();
        Set<String> seen = new LinkedHashSet<>();

        if (snippets != null) {
            for (ContextSnippet snippet : snippets) {
                String uri = safeText(snippet.uri());
                if (!hasText(uri) || !seen.add(uri)) {
                    continue;
                }
                String line = firstNonBlank(snippet.abstractText(), snippet.content(), snippet.title());
                if (hasText(line)) {
                    items.add(line.trim());
                }
            }
        }

        if (memories != null) {
            for (MemoryRecordEntity memory : memories) {
                String key = memory.getUuid().toString();
                if (!seen.add(key)) {
                    continue;
                }
                String line = firstNonBlank(memory.getAbstractText(), memory.getContent(), memory.getTitle());
                if (hasText(line)) {
                    items.add(line.trim());
                }
            }
        }

        return items;
    }

    private List<String> extractResourceLines(List<ContextSnippet> snippets) {
        if (snippets == null || snippets.isEmpty()) {
            return Collections.emptyList();
        }
        List<String> items = new ArrayList<>();
        for (ContextSnippet snippet : snippets) {
            String line = firstNonBlank(snippet.abstractText(), snippet.content(), snippet.title(), snippet.uri());
            if (hasText(line)) {
                items.add(line.trim());
            }
        }
        return items;
    }

    private List<String> defaultList(List<String> values) {
        return values == null ? Collections.emptyList() : values;
    }

    private String joinLines(List<String> values) {
        if (values == null || values.isEmpty()) {
            return "";
        }
        return values.stream()
                .filter(this::hasText)
                .map(String::trim)
                .collect(Collectors.joining("\n"));
    }

    private String firstNonBlank(String... values) {
        if (values == null) {
            return "";
        }
        for (String value : values) {
            if (hasText(value)) {
                return value;
            }
        }
        return "";
    }

    private boolean hasText(String str) {
        return str != null && !str.trim().isEmpty();
    }

    private String safeText(String str) {
        return hasText(str) ? str.trim() : "";
    }

    private String nullableText(String str) {
        return hasText(str) ? str.trim() : null;
    }
}
