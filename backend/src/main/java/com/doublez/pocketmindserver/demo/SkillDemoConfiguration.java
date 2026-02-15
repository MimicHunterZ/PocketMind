package com.doublez.pocketmindserver.demo;

import org.springaicommunity.agent.tools.FileSystemTools;
import org.springaicommunity.agent.tools.ShellTools;
import org.springaicommunity.agent.tools.SkillsTool;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.SimpleLoggerAdvisor;
import org.springframework.ai.support.ToolCallbacks;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * Skill Demo 全局配置
 * 统一组装工具链、默认上下文和可观测日志 Advisor
 */
@Configuration
public class SkillDemoConfiguration {

    @Value("${pocketmind.observability.tool.log-full-payload:false}")
    private boolean logFullPayload;

    @Value("${pocketmind.observability.tool.max-payload-length:4000}")
    private int maxPayloadLength;

    @Value("${pocketmind.observability.tool.log-tool-context:true}")
    private boolean logToolContext;

    @Value("${pocketmind.context-engineering.tool-result.enabled:true}")
    private boolean contextEngineeringEnabled;

    @Value("${pocketmind.context-engineering.tool-result.max-lines:80}")
    private int contextEngineeringMaxLines;

    @Value("${pocketmind.context-engineering.tool-result.max-chars:4000}")
    private int contextEngineeringMaxChars;

    @Bean("skillDemoChatClient")
    public ChatClient skillDemoChatClient(ChatClient.Builder chatClientBuilder) {
        return skillOptimizedChatClient(chatClientBuilder);
    }

    @Bean("skillOptimizedChatClient")
    public ChatClient skillOptimizedChatClient(ChatClient.Builder chatClientBuilder) {
        ToolResultContextEngineer contextEngineer = new ToolResultContextEngineer(
                contextEngineeringEnabled,
                contextEngineeringMaxLines,
                contextEngineeringMaxChars
        );
        ToolCallback[] observedCallbacks = observedToolCallbacks(contextEngineer);

        return chatClientBuilder
                .defaultAdvisors(new SimpleLoggerAdvisor())
                .defaultToolCallbacks(observedCallbacks)
                .defaultToolContext(Map.of("foo", "bar", "contextMode", "optimized"))
                .build();
    }

    @Bean("skillBaselineChatClient")
    public ChatClient skillBaselineChatClient(ChatClient.Builder chatClientBuilder) {
        ToolResultContextEngineer contextEngineer = new ToolResultContextEngineer(false, Integer.MAX_VALUE, Integer.MAX_VALUE);
        ToolCallback[] observedCallbacks = observedToolCallbacks(contextEngineer);

        return chatClientBuilder
                .defaultAdvisors(new SimpleLoggerAdvisor())
                .defaultToolCallbacks(observedCallbacks)
                .defaultToolContext(Map.of("foo", "bar", "contextMode", "baseline"))
                .build();
    }

    private ToolCallback[] observedToolCallbacks(ToolResultContextEngineer contextEngineer) {
        ToolCallback[] skillCallbacks = resolveToolCallbacks(SkillsTool.builder()
                .addSkillsDirectory(".claude/skills")
                .build());
        ToolCallback[] fileCallbacks = resolveToolCallbacks(FileSystemTools.builder().build());
        ToolCallback[] shellCallbacks = resolveToolCallbacks(ShellTools.builder().build());

        List<ToolCallback> allCallbacks = new ArrayList<>();
        allCallbacks.addAll(Arrays.asList(skillCallbacks));
        allCallbacks.addAll(Arrays.asList(fileCallbacks));
        allCallbacks.addAll(Arrays.asList(shellCallbacks));

        return allCallbacks.stream()
        .map(callback -> new ObservedToolCallback(callback, contextEngineer, logFullPayload, maxPayloadLength, logToolContext))
                .toArray(ToolCallback[]::new);
    }

    private ToolCallback[] resolveToolCallbacks(Object toolSource) {
        if (toolSource instanceof ToolCallback toolCallback) {
            return new ToolCallback[]{toolCallback};
        }
        if (toolSource instanceof ToolCallback[] callbacks) {
            return callbacks;
        }
        return ToolCallbacks.from(toolSource);
    }
}
