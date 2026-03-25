package com.doublez.pocketmindserver.shared.util;

import org.springframework.ai.chat.messages.SystemMessage;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.prompt.ChatOptions;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.chat.prompt.PromptTemplate;
import org.springframework.ai.template.st.StTemplateRenderer;
import org.springframework.core.io.Resource;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class PromptBuilder {

    private static final Map<Resource, String> templateCache = new ConcurrentHashMap<>();

    private static String getCachedTemplateString(Resource template) throws IOException {
        String content = templateCache.get(template);
        if (content != null) {
            return content;
        }
        content = template.getContentAsString(StandardCharsets.UTF_8);
        templateCache.put(template, content);
        return content;
    }

    public static String render(Resource template, Map<String, Object> variables) throws IOException {
        String templateString = getCachedTemplateString(template);

        PromptTemplate promptTemplate = PromptTemplate.builder()
                .renderer(StTemplateRenderer.builder().startDelimiterToken('<').endDelimiterToken('>').build())
                .template(templateString)
                .build();

        return promptTemplate.render(variables);
    }

    /**
     * 直接组装静态的 System 消息和动态的 User 消息，生成完整的 Prompt 对象
     */
    public static Prompt build(Resource systemTemplate, Resource userTemplate, Map<String, Object> userVariables) throws IOException {
        String systemContent = getCachedTemplateString(systemTemplate);
        SystemMessage systemMessage = new SystemMessage(systemContent);

        String userContent = render(userTemplate, userVariables);
        UserMessage userMessage = new UserMessage(userContent);

        return new Prompt(List.of(systemMessage, userMessage));
    }

    /**
     * 组装 Prompt 并携带模型 options（如 OpenAiChatOptions）。
     */
    public static Prompt build(Resource systemTemplate,
                               Resource userTemplate,
                               Map<String, Object> userVariables,
                               ChatOptions options) throws IOException {
        String systemContent = getCachedTemplateString(systemTemplate);
        SystemMessage systemMessage = new SystemMessage(systemContent);

        String userContent = render(userTemplate, userVariables);
        UserMessage userMessage = new UserMessage(userContent);

        // Spring AI Prompt 支持携带 options（ChatOptions），用于启用 JSON mode 等能力。
        return new Prompt(List.of(systemMessage, userMessage), options);
    }
}
