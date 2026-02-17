package com.doublez.pocketmindserver.demo;

import org.springaicommunity.agent.tools.FileSystemTools;
import org.springaicommunity.agent.tools.ShellTools;
import org.springaicommunity.agent.tools.SkillsTool;
import com.doublez.pocketmindserver.ai.config.AiProvidersProperties;
import com.doublez.pocketmindserver.ai.config.AiRole;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.SimpleLoggerAdvisor;
import org.springframework.ai.chat.client.advisor.ToolCallAdvisor;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.ai.support.ToolCallbacks;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.micrometer.observation.ObservationRegistry;
import org.springframework.core.Ordered;
import org.springframework.core.retry.RetryTemplate;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.http.client.BufferingClientHttpRequestFactory;
import org.springframework.web.client.RestClient;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Skill Demo 全局配置
 * 统一组装工具链、默认上下文和可观测日志 Advisor
 */
@Configuration
@ConditionalOnProperty(prefix = "pocketmind.demo", name = "enabled", havingValue = "true")
public class SkillDemoConfiguration {

    @Value("${pocketmind.observability.tool.log-full-payload:false}")
    private boolean logFullPayload;

    @Value("${pocketmind.observability.tool.max-payload-length:4000}")
    private int maxPayloadLength;

    @Value("${pocketmind.observability.tool.log-tool-context:true}")
    private boolean logToolContext;

    @Value("${pocketmind.observability.chat-client-simple-logger-enabled:false}")
    private boolean chatClientSimpleLoggerEnabled;

    @Value("${pocketmind.demo.tool-response-pruning.default-window-tokens:64000}")
    private int defaultWindowTokens;

    @Value("${pocketmind.demo.tool-response-pruning.start-ratio:0.75}")
    private double toolResponsePruneStartRatio;

    @Value("${pocketmind.demo.tool-response-pruning.keep-recent-tool-responses:2}")
    private int keepRecentToolResponses;

    // 默认用 ../.claude/skills：本项目通常从 backend 目录启动 Spring Boot。
    @Value("${pocketmind.demo.skills-path:../.claude/skills}")
    private String skillsPath;

    @Value("${pocketmind.demo.http.buffering-enabled:true}")
    private boolean bufferingEnabled;

    /**
     * demo 专用模型：只影响 /demo/skill/*
     * 1) 通过 RestClient interceptor 捕获 DeepSeek HTTP 的 request/response body，写入 Langfuse 便于排查。
     * 2) 使用 BufferingClientHttpRequestFactory 缓存 response body，避免“读取一次后下游解析失败”。
     *
     * 注意：BufferingClientHttpRequestFactory 会把响应体完整读入内存；如果未来启用流式输出，建议将
     * pocketmind.demo.http.buffering-enabled 设为 false，以免破坏流式效果或放大内存占用。
     */
    @Bean("skillDemoOpenAiChatModel")
    public OpenAiChatModel skillDemoOpenAiChatModel(AiProvidersProperties providers,
                                                    ObservationRegistry observationRegistry,
                                                    RetryTemplate retryTemplate) {
        AiProvidersProperties.ProviderConfig providerConfig = providers.resolveConfig(AiRole.PRIMARY);

        SimpleClientHttpRequestFactory baseFactory = new SimpleClientHttpRequestFactory();
        RestClient.Builder restClientBuilder = RestClient.builder()
            .requestFactory(bufferingEnabled ? new BufferingClientHttpRequestFactory(baseFactory) : baseFactory)
                .requestInterceptor(new LangfuseHttpBodyCaptureInterceptor());

        WebClient.Builder webClientBuilder = WebClient.builder();

        OpenAiApi api = OpenAiApi.builder()
            .baseUrl(providerConfig.baseUrl())
            .apiKey(providerConfig.apiKey())
                .restClientBuilder(restClientBuilder)
                .webClientBuilder(webClientBuilder)
                .build();

        OpenAiChatOptions options = OpenAiChatOptions.builder()
            .model(providerConfig.model())
                .build();

        return new OpenAiChatModel(
                api,
                options,
                org.springframework.ai.model.tool.ToolCallingManager.builder().build(),
                retryTemplate,
                observationRegistry
        );
    }

    @Bean("skillBaselineChatClient")
    public ChatClient skillBaselineChatClient(AiProvidersProperties providers,
                                              OpenAiChatModel skillDemoOpenAiChatModel,
                                              ObjectMapper objectMapper) {
        String modelName = providers.resolveConfig(AiRole.PRIMARY).model();
        return buildSkillChatClient(providers, skillDemoOpenAiChatModel, objectMapper, modelName, "raw", false);
    }

    /**
     * 仅做“工具结果忽略”：当占用率 >= 75% 时丢弃早期的 ToolResponseMessage。
     */
    @Bean("skillPrunedChatClient")
    public ChatClient skillPrunedChatClient(AiProvidersProperties providers,
                                            OpenAiChatModel skillDemoOpenAiChatModel,
                                            ObjectMapper objectMapper) {
        String modelName = providers.resolveConfig(AiRole.PRIMARY).model();
        return buildSkillChatClient(providers, skillDemoOpenAiChatModel, objectMapper, modelName, "pruned", true);
    }

    private TrustedModelContextWindowResolver buildContextWindowResolver(AiProvidersProperties providers) {
        // demo 也统一从 pocketmind.ai.providers.configs.*.window-tokens 读取，避免重复配置与歧义。
        return new TrustedModelContextWindowResolver(
                defaultWindowTokens,
                resolveWindowTokensFromProviders(providers)
        );
    }

    private Map<String, Integer> resolveWindowTokensFromProviders(AiProvidersProperties providers) {
        if (providers == null || providers.configs() == null || providers.configs().isEmpty()) {
            return Map.of();
        }
        Map<String, Integer> map = new HashMap<>();
        for (AiProvidersProperties.ProviderConfig cfg : providers.configs().values()) {
            if (cfg == null) {
                continue;
            }
            if (cfg.model() == null || cfg.model().isBlank()) {
                continue;
            }
            if (cfg.windowTokens() <= 0) {
                continue;
            }
            map.put(cfg.model().trim(), cfg.windowTokens());
        }
        return map;
    }

    private ChatClient buildSkillChatClient(AiProvidersProperties providers,
                                           OpenAiChatModel chatModel,
                                           ObjectMapper objectMapper,
                                           String modelName,
                                           String contextMode,
                                           boolean enableToolResponsePruning) {
        ToolCallback[] observedCallbacks = observedToolCallbacks(modelName);

        ChatClient.Builder builder = ChatClient.builder(chatModel)
                .defaultToolCallbacks(observedCallbacks)
                .defaultToolContext(Map.of("contextMode", contextMode));

        applyDefaultAdvisors(providers, builder, objectMapper, enableToolResponsePruning, modelName);
        return builder.build();
    }

    private void applyDefaultAdvisors(AiProvidersProperties providers,
                                     ChatClient.Builder builder,
                                     ObjectMapper objectMapper,
                                     boolean enableToolResponsePruning,
                                     String modelName) {
        if (enableToolResponsePruning) {
            // demo 的剪枝窗口也统一与 providers 配置一致。
            TrustedModelContextWindowResolver resolver = buildContextWindowResolver(providers);
            PruningToolCallAdvisor toolCallAdvisor = new PruningToolCallAdvisor(
                org.springframework.ai.model.tool.ToolCallingManager.builder().build(),
                    toolResponsePruneStartRatio,
                    keepRecentToolResponses,
                resolver,
                modelName
            );

            if (chatClientSimpleLoggerEnabled) {
                builder.defaultAdvisors(
                        new LangfuseChatObservationAdvisor(objectMapper),
                        toolCallAdvisor,
                        new SimpleLoggerAdvisor()
                );
                return;
            }

            builder.defaultAdvisors(
                    new LangfuseChatObservationAdvisor(objectMapper),
                toolCallAdvisor
            );
            return;
        }

        ToolCallAdvisor toolCallAdvisor = ToolCallAdvisor.builder()
            .advisorOrder(Ordered.HIGHEST_PRECEDENCE + 100)
            .build();

        if (chatClientSimpleLoggerEnabled) {
            builder.defaultAdvisors(
                    new LangfuseChatObservationAdvisor(objectMapper),
                    toolCallAdvisor,
                    new SimpleLoggerAdvisor()
            );
            return;
        }

        builder.defaultAdvisors(
                new LangfuseChatObservationAdvisor(objectMapper),
                toolCallAdvisor
        );
    }

    private ToolCallback[] observedToolCallbacks(String modelName) {
        ToolCallback[] skillCallbacks = resolveToolCallbacks(SkillsTool.builder()
                .addSkillsDirectory(skillsPath)
                .build());
        ToolCallback[] fileCallbacks = resolveToolCallbacks(FileSystemTools.builder().build());
        ToolCallback[] shellCallbacks = resolveToolCallbacks(ShellTools.builder().build());

        List<ToolCallback> allCallbacks = new ArrayList<>();
        allCallbacks.addAll(Arrays.asList(skillCallbacks));
        allCallbacks.addAll(Arrays.asList(fileCallbacks));
        allCallbacks.addAll(Arrays.asList(shellCallbacks));

        return allCallbacks.stream()
        .map(callback -> new ObservedToolCallback(
                callback,
                modelName,
                logFullPayload,
                maxPayloadLength,
                logToolContext
        ))
                .toArray(ToolCallback[]::new);
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
}
