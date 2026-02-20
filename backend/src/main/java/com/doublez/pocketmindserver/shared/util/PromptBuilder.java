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

public class PromptBuilder {

    /**
     * 将包含 <xxx> 的 Resource 模板动态渲染为纯文本 String
     */
    public static String render(Resource template, Map<String, Object> variables) throws IOException {
        String templateString = template.getContentAsString(StandardCharsets.UTF_8);

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
        // 1. 读取系统提示词
        String systemContent = systemTemplate.getContentAsString(StandardCharsets.UTF_8);
        SystemMessage systemMessage = new SystemMessage(systemContent);

        // 2. 动态渲染用户提示词 (替换 <key>)
        String userContent = render(userTemplate, userVariables);
        UserMessage userMessage = new UserMessage(userContent);

        // 3. 组合并返回最终的 Prompt
        return new Prompt(List.of(systemMessage, userMessage));
    }

    /**
     * 组装 Prompt 并携带模型 options（如 OpenAiChatOptions）。
     */
    public static Prompt build(Resource systemTemplate,
                               Resource userTemplate,
                               Map<String, Object> userVariables,
                               ChatOptions options) throws IOException {
        String systemContent = systemTemplate.getContentAsString(StandardCharsets.UTF_8);
        SystemMessage systemMessage = new SystemMessage(systemContent);

        String userContent = render(userTemplate, userVariables);
        UserMessage userMessage = new UserMessage(userContent);

        // Spring AI Prompt 支持携带 options（ChatOptions），用于启用 JSON mode 等能力。
        return new Prompt(List.of(systemMessage, userMessage), options);
    }
}