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

    @Bean("skillDemoChatClient")
    public ChatClient skillDemoChatClient(ChatClient.Builder chatClientBuilder) {
        ToolCallback[] observedCallbacks = observedToolCallbacks();

        return chatClientBuilder
                .defaultAdvisors(new SimpleLoggerAdvisor())
                .defaultToolCallbacks(observedCallbacks)
                .defaultToolContext(Map.of("foo", "bar"))
                .build();
    }

    private ToolCallback[] observedToolCallbacks() {
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
                .map(callback -> new ObservedToolCallback(callback, logFullPayload, maxPayloadLength, logToolContext))
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
