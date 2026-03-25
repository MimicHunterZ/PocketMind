package com.doublez.pocketmindserver.ai.application.context;

import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ContextTemplateRenderTest {

    @Test
    void noteSystemTemplate_shouldRenderWithoutMissingVariables() {
        Resource template = new ClassPathResource("prompts/chat/note_system.md");
        Map<String, Object> variables = buildCommonVariables();
        variables.put("noteTitle", "测试笔记");
        variables.put("noteContent", "这是正文");
        variables.put("ocrTextsBlock", "- ocr line");

        String rendered = assertDoesNotThrow(() -> PromptBuilder.render(template, variables));
        assertTrue(rendered.contains("测试笔记"));
    }

    @Test
    void globalSystemTemplate_shouldRenderWithoutMissingVariables() {
        Resource template = new ClassPathResource("prompts/chat/global_system.md");
        Map<String, Object> variables = buildCommonVariables();

        String rendered = assertDoesNotThrow(() -> PromptBuilder.render(template, variables));
        assertTrue(rendered.contains("强制底层行为准则"));
    }

    private Map<String, Object> buildCommonVariables() {
        Map<String, Object> variables = new HashMap<>();
        variables.put("persona", null);
        variables.put("profilesBlock", "- profile");
        variables.put("preferencesBlock", "- preference");
        variables.put("relevantMemoriesBlock", "- [Hit] title: abstract");
        variables.put("resourcesBlock", "### 📄 title\n> 来源: uri\n> 相关内容片段:\n> content");
        variables.put("noteTitle", "");
        variables.put("noteContent", "");
        variables.put("webSourceUrl", "");
        variables.put("webClipContent", "");
        variables.put("ocrTextsBlock", "");
        return variables;
    }
}
