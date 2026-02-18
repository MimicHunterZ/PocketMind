package com.doublez.pocketmindserver.ai.config;

import org.springaicommunity.agent.tools.FileSystemTools;
import org.springaicommunity.agent.tools.ShellTools;
import org.springaicommunity.agent.tools.SkillsTool;
import org.springframework.ai.support.ToolCallbacks;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import org.springframework.beans.factory.support.DefaultListableBeanFactory;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * AI 工具注册。
 * chat client 配置的时候按 modelName 做过滤。
 */
@Configuration
@EnableConfigurationProperties(AiToolsProperties.class)
@ConditionalOnProperty(prefix = "pocketmind.ai.tools", name = "enabled", havingValue = "true")
public class AiToolsConfiguration {

    @Bean
    public BeanFactoryPostProcessor aiToolCallbackRegistrar(AiToolsProperties props) {
        return beanFactory -> {
            if (!(beanFactory instanceof DefaultListableBeanFactory dlbf)) {
                return;
            }

            List<ToolCallback> allCallbacks = new ArrayList<>();
            allCallbacks.addAll(Arrays.asList(resolveToolCallbacks(
                    SkillsTool.builder().addSkillsDirectory(props.skillsPath()).build()
            )));
            allCallbacks.addAll(Arrays.asList(resolveToolCallbacks(FileSystemTools.builder().build())));
            allCallbacks.addAll(Arrays.asList(resolveToolCallbacks(ShellTools.builder().build())));

            int index = 0;
            for (ToolCallback callback : allCallbacks) {
                if (callback == null) {
                    continue;
                }
                callback.getToolDefinition();
                String toolName = callback.getToolDefinition().name();
                String beanName = "aiToolCallback_" + sanitize(toolName) + "_" + index;
                if (!dlbf.containsSingleton(beanName)) {
                    dlbf.registerSingleton(beanName, callback);
                }
                index++;
            }
        };
    }

    private ToolCallback[] resolveToolCallbacks(Object toolSource) {
        // Spring AI 2.0.0-M2：ToolCallbacks.from(Object) 不一定能正确识别 ToolCallback 实例，
        // 可能误走 MethodToolCallbackProvider（要求存在 @Tool 方法）从而导致启动失败。
        if (toolSource instanceof ToolCallback toolCallback) {
            return new ToolCallback[]{toolCallback};
        }
        if (toolSource instanceof ToolCallback[] callbacks) {
            return callbacks;
        }
        return ToolCallbacks.from(toolSource);
    }

    private String sanitize(String raw) {
        if (raw == null || raw.isBlank()) {
            return "tool";
        }
        return raw.trim().replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}
