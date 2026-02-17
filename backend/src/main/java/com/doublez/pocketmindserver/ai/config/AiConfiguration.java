package com.doublez.pocketmindserver.ai.config;

import com.doublez.pocketmindserver.ai.context.PruningToolCallAdvisor;
import com.doublez.pocketmindserver.ai.context.ToolResultContextEngineeringProperties;
import com.doublez.pocketmindserver.ai.context.TrustedModelContextWindowResolver;
import com.doublez.pocketmindserver.ai.observability.AiObservabilityProperties;
import com.doublez.pocketmindserver.ai.observability.langfuse.LangfuseChatObservationAdvisor;
import com.doublez.pocketmindserver.ai.observability.langfuse.AiLangfuseHttpBodyCaptureInterceptor;
import com.doublez.pocketmindserver.ai.tools.observability.ObservedToolCallback;
import com.fasterxml.jackson.databind.json.JsonMapper;
import io.micrometer.observation.ObservationRegistry;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.SimpleLoggerAdvisor;
import org.springframework.ai.chat.client.advisor.ToolCallAdvisor;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.model.tool.ToolCallingManager;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.retry.RetryTemplate;
import org.springframework.http.client.BufferingClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;
import org.springframework.beans.factory.SmartInitializingSingleton;
import org.springframework.util.StringUtils;
import java.util.Objects;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * AI 模块配置
 * 配置 ChatClient Bean 用于 AI 服务
 */
@Configuration
public class AiConfiguration {

    /**
     * 启动期校验：vision 的降级链路必须成对配置。
     */
    @Bean
    public SmartInitializingSingleton aiProvidersStartupValidator(AiProvidersProperties providers) {
        return () -> validateVisionFailoverRoutes(providers);
    }

    private void validateVisionFailoverRoutes(AiProvidersProperties providers) {
        if (providers == null || providers.routes() == null) {
            return;
        }

        String visionSecondary = providers.routes().visionSecondary();
        String visionFallback = providers.routes().visionFallback();

        boolean hasVisionSecondary = StringUtils.hasText(visionSecondary);
        boolean hasVisionFallback = StringUtils.hasText(visionFallback);

        if (hasVisionSecondary ^ hasVisionFallback) {
            throw new IllegalStateException("vision-secondary 与 vision-fallback 必须同时配置（或同时不配）");
        }

        // 若配置了链路，则确保 providerKey 存在且 config 合法。
        if (hasVisionSecondary) {
            providers.resolveConfigByProviderKey(visionSecondary, "vision-secondary");
            providers.resolveConfigByProviderKey(visionFallback, "vision-fallback");
        }
    }

    // region ChatModel

    @Bean("primaryChatModel")
    public OpenAiChatModel primaryChatModel(AiProvidersProperties providers,
                                            AiHttpClientProperties httpClientProperties,
                                            AiObservabilityProperties observabilityProperties,
                                            ObservationRegistry observationRegistry,
                                            RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiRole.PRIMARY), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean("secondaryChatModel")
    public OpenAiChatModel secondaryChatModel(AiProvidersProperties providers,
                                              AiHttpClientProperties httpClientProperties,
                                              AiObservabilityProperties observabilityProperties,
                                              ObservationRegistry observationRegistry,
                                              RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiRole.SECONDARY), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean("fallbackChatModel")
    public OpenAiChatModel fallbackChatModel(AiProvidersProperties providers,
                                             AiHttpClientProperties httpClientProperties,
                                             AiObservabilityProperties observabilityProperties,
                                             ObservationRegistry observationRegistry,
                                             RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiRole.FALLBACK), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean("visionChatModel")
    public OpenAiChatModel visionChatModel(AiProvidersProperties providers,
                                           AiHttpClientProperties httpClientProperties,
                                           AiObservabilityProperties observabilityProperties,
                                           ObservationRegistry observationRegistry,
                                           RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiRole.VISION), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean("imageChatModel")
    @ConditionalOnProperty(prefix = "pocketmind.ai.providers.routes", name = "image")
    public OpenAiChatModel imageChatModel(AiProvidersProperties providers,
                                          AiHttpClientProperties httpClientProperties,
                                          AiObservabilityProperties observabilityProperties,
                                          ObservationRegistry observationRegistry,
                                          RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiRole.IMAGE), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean("audioChatModel")
    @ConditionalOnProperty(prefix = "pocketmind.ai.providers.routes", name = "audio")
    public OpenAiChatModel audioChatModel(AiProvidersProperties providers,
                                          AiHttpClientProperties httpClientProperties,
                                          AiObservabilityProperties observabilityProperties,
                                          ObservationRegistry observationRegistry,
                                          RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiRole.AUDIO), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    private OpenAiChatModel buildChatModel(AiProvidersProperties.ProviderConfig config,
                                           AiHttpClientProperties httpClientProperties,
                                           AiObservabilityProperties observabilityProperties,
                                           ObservationRegistry observationRegistry,
                                           RetryTemplate retryTemplate) {
        Objects.requireNonNull(config, "config");

        // 使用阻塞型 requestFactory 显式控制超时，避免 Reactor Netty 默认超时导致 ReadTimeout。
        SimpleClientHttpRequestFactory baseFactory = new SimpleClientHttpRequestFactory();
        baseFactory.setConnectTimeout(httpClientProperties.connectTimeoutMs());
        baseFactory.setReadTimeout(httpClientProperties.readTimeoutMs());
        RestClient.Builder restClientBuilder = RestClient.builder()
            .requestFactory(new BufferingClientHttpRequestFactory(baseFactory));

        // Langfuse HTTP body 捕获（主项目独立开关，不影响 demo）。
        if (observabilityProperties != null
            && observabilityProperties.langfuse() != null
            && observabilityProperties.langfuse().enabled()
            && observabilityProperties.langfuse().httpBodyCaptureEnabled()) {
            restClientBuilder.requestInterceptor(new AiLangfuseHttpBodyCaptureInterceptor(
                observabilityProperties.langfuse().logFullPayload(),
                observabilityProperties.langfuse().maxPayloadLength()
            ));
        }

        OpenAiApi api = OpenAiApi.builder()
                .baseUrl(config.baseUrl())
                .apiKey(config.apiKey())
                .restClientBuilder(restClientBuilder)
                .build();

        OpenAiChatOptions options = OpenAiChatOptions.builder()
                .model(config.model())
                .build();

        return new OpenAiChatModel(
                api,
                options,
                ToolCallingManager.builder().build(),
                retryTemplate,
                observationRegistry
        );
    }

    // region Vision failover chain (optional)

    @Bean("visionSecondaryChatModel")
    @ConditionalOnProperty(prefix = "pocketmind.ai.providers.routes", name = "vision-secondary")
    public OpenAiChatModel visionSecondaryChatModel(AiProvidersProperties providers,
                                                    AiHttpClientProperties httpClientProperties,
                                                    AiObservabilityProperties observabilityProperties,
                                                    ObservationRegistry observationRegistry,
                                                    RetryTemplate retryTemplate) {
        String providerKey = providers.routes() == null ? null : providers.routes().visionSecondary();
        AiProvidersProperties.ProviderConfig config = providers.resolveConfigByProviderKey(providerKey, "vision-secondary");
        return buildChatModel(config, httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean("visionFallbackChatModel")
    @ConditionalOnProperty(prefix = "pocketmind.ai.providers.routes", name = "vision-fallback")
    public OpenAiChatModel visionFallbackChatModel(AiProvidersProperties providers,
                                                   AiHttpClientProperties httpClientProperties,
                                                   AiObservabilityProperties observabilityProperties,
                                                   ObservationRegistry observationRegistry,
                                                   RetryTemplate retryTemplate) {
        String providerKey = providers.routes() == null ? null : providers.routes().visionFallback();
        AiProvidersProperties.ProviderConfig config = providers.resolveConfigByProviderKey(providerKey, "vision-fallback");
        return buildChatModel(config, httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    // region ChatClient（多角色）

    @Bean("primaryChatClient")
    public ChatClient primaryChatClient(@Qualifier("primaryChatModel") OpenAiChatModel primaryChatModel,
                                        AiProvidersProperties providers,
                                        JsonMapper aiJsonMapper,
                                        AiObservabilityProperties observabilityProperties,
                                        ToolResultContextEngineeringProperties toolResultProps,
                                        List<ToolCallback> toolCallbacks) {
        return buildChatClient(primaryChatModel, providers, providers.resolveConfig(AiRole.PRIMARY).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean("secondaryChatClient")
    public ChatClient secondaryChatClient(@Qualifier("secondaryChatModel") OpenAiChatModel secondaryChatModel,
                                          AiProvidersProperties providers,
                                          JsonMapper aiJsonMapper,
                                          AiObservabilityProperties observabilityProperties,
                                          ToolResultContextEngineeringProperties toolResultProps,
                                          List<ToolCallback> toolCallbacks) {
        return buildChatClient(secondaryChatModel, providers, providers.resolveConfig(AiRole.SECONDARY).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean("fallbackChatClient")
    public ChatClient fallbackChatClient(@Qualifier("fallbackChatModel") OpenAiChatModel fallbackChatModel,
                                         AiProvidersProperties providers,
                                         JsonMapper aiJsonMapper,
                                         AiObservabilityProperties observabilityProperties,
                                         ToolResultContextEngineeringProperties toolResultProps,
                                         List<ToolCallback> toolCallbacks) {
        return buildChatClient(fallbackChatModel, providers, providers.resolveConfig(AiRole.FALLBACK).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean("visionChatClient")
    public ChatClient visionChatClient(@Qualifier("visionChatModel") OpenAiChatModel visionChatModel,
                                       AiProvidersProperties providers,
                                       JsonMapper aiJsonMapper,
                                       AiObservabilityProperties observabilityProperties,
                                       ToolResultContextEngineeringProperties toolResultProps,
                                       List<ToolCallback> toolCallbacks) {
        return buildChatClient(visionChatModel, providers, providers.resolveConfig(AiRole.VISION).model(), aiJsonMapper,
                observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean("visionSecondaryChatClient")
    @ConditionalOnProperty(prefix = "pocketmind.ai.providers.routes", name = "vision-secondary")
    public ChatClient visionSecondaryChatClient(@Qualifier("visionSecondaryChatModel") OpenAiChatModel chatModel,
                                                AiProvidersProperties providers,
                                                JsonMapper aiJsonMapper,
                                                AiObservabilityProperties observabilityProperties,
                                                ToolResultContextEngineeringProperties toolResultProps,
                                                List<ToolCallback> toolCallbacks) {
        String providerKey = providers.routes() == null ? null : providers.routes().visionSecondary();
        String modelName = providers.resolveConfigByProviderKey(providerKey, "vision-secondary").model();
        return buildChatClient(chatModel, providers, modelName, aiJsonMapper, observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean("visionFallbackChatClient")
    @ConditionalOnProperty(prefix = "pocketmind.ai.providers.routes", name = "vision-fallback")
    public ChatClient visionFallbackChatClient(@Qualifier("visionFallbackChatModel") OpenAiChatModel chatModel,
                                               AiProvidersProperties providers,
                                               JsonMapper aiJsonMapper,
                                               AiObservabilityProperties observabilityProperties,
                                               ToolResultContextEngineeringProperties toolResultProps,
                                               List<ToolCallback> toolCallbacks) {
        String providerKey = providers.routes() == null ? null : providers.routes().visionFallback();
        String modelName = providers.resolveConfigByProviderKey(providerKey, "vision-fallback").model();
        return buildChatClient(chatModel, providers, modelName, aiJsonMapper, observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean("imageChatClient")
    @ConditionalOnProperty(prefix = "pocketmind.ai.providers.routes", name = "image")
    public ChatClient imageChatClient(@Qualifier("imageChatModel") OpenAiChatModel imageChatModel,
                                      AiProvidersProperties providers,
                                      JsonMapper aiJsonMapper,
                                      AiObservabilityProperties observabilityProperties,
                                      ToolResultContextEngineeringProperties toolResultProps,
                                      List<ToolCallback> toolCallbacks) {
        return buildChatClient(imageChatModel, providers, providers.resolveConfig(AiRole.IMAGE).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean("audioChatClient")
    @ConditionalOnProperty(prefix = "pocketmind.ai.providers.routes", name = "audio")
    public ChatClient audioChatClient(@Qualifier("audioChatModel") OpenAiChatModel audioChatModel,
                                      AiProvidersProperties providers,
                                      JsonMapper aiJsonMapper,
                                      AiObservabilityProperties observabilityProperties,
                                      ToolResultContextEngineeringProperties toolResultProps,
                                      List<ToolCallback> toolCallbacks) {
        return buildChatClient(audioChatModel, providers, providers.resolveConfig(AiRole.AUDIO).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    private ChatClient buildChatClient(OpenAiChatModel chatModel,
                           AiProvidersProperties providers,
                                       String modelName,
                                       JsonMapper aiJsonMapper,
                                       AiObservabilityProperties observabilityProperties,
                                       ToolResultContextEngineeringProperties toolResultContextEngineeringProperties,
                                       List<ToolCallback> toolCallbacks) {
        ChatClient.Builder builder = ChatClient.builder(chatModel);

        // 1) Langfuse 展示适配（业务侧独立开关，禁止使用 demo 配置）。
        if (observabilityProperties.langfuse().enabled()) {
            builder.defaultAdvisors(new LangfuseChatObservationAdvisor(aiJsonMapper));
        }

        // 2) 工具调用：默认 advisor（非 demo），以及可选的 tool-result 剪枝。
        //    注意：只有在存在 tool callback 时才挂载 tool advisor，避免无工具场景引入额外复杂度。
        if (toolCallbacks != null && !toolCallbacks.isEmpty()) {
            ToolCallAdvisor toolCallAdvisor = buildToolCallAdvisor(providers, toolResultContextEngineeringProperties, modelName);
            builder.defaultAdvisors(toolCallAdvisor);
        }

        // 3) ChatClient 调试日志（业务侧独立开关）。
        if (observabilityProperties.chat().simpleLoggerEnabled()) {
            builder.defaultAdvisors(new SimpleLoggerAdvisor());
        }

        // 4) 默认工具回调：如果业务侧注册了 ToolCallback，则默认启用（并按开关做观测包装）。
        if (toolCallbacks != null && !toolCallbacks.isEmpty()) {
            builder.defaultToolCallbacks(wrapToolCallbacks(toolCallbacks, observabilityProperties, modelName));
        }

        return builder.build();
    }

    // endregion

    private ToolCallAdvisor buildToolCallAdvisor(AiProvidersProperties providers,
                                                 ToolResultContextEngineeringProperties props,
                                                 String modelName) {
        if (props != null && props.enabled()) {
            Map<String, Integer> windowTokens = resolveWindowTokensFromProviders(providers);
            if (windowTokens.isEmpty()) {
                if (props.modelWindowTokens() != null && !props.modelWindowTokens().isEmpty()) {
                    windowTokens = props.modelWindowTokens();
                }
            }

            // 强约束：开启剪枝时，必须为当前模型显式配置上下文窗口。
            if (!hasExplicitWindowTokensForModel(windowTokens, modelName)) {
            throw new IllegalStateException(
                "已开启 pocketmind.context-engineering.tool-result.enabled=true，但未为当前模型配置 window-tokens：model="
                    + (modelName == null ? "" : modelName)
                                + "。请在 pocketmind.ai.providers.configs.*.window-tokens 或 pocketmind.context-engineering.tool-result.model-window-tokens 中显式配置。"
            );
            }

            TrustedModelContextWindowResolver resolver = new TrustedModelContextWindowResolver(
                    props.defaultWindowTokens(),
                    windowTokens
            );
            return new PruningToolCallAdvisor(
                    ToolCallingManager.builder().build(),
                    props.compressStartRatio(),
                    props.keepRecentToolResponses(),
                    resolver,
                    modelName
            );
        }

        return ToolCallAdvisor.builder()
                .advisorOrder(Ordered.HIGHEST_PRECEDENCE + 100)
                .build();
    }

    private boolean hasExplicitWindowTokensForModel(Map<String, Integer> windowTokens, String modelName) {
        if (windowTokens == null || windowTokens.isEmpty()) {
            return false;
        }
        if (modelName == null || modelName.isBlank()) {
            return false;
        }

        String raw = modelName.trim();
        Integer exact = windowTokens.get(raw);
        if (exact != null && exact > 0) {
            return true;
        }

        String normalized = normalizeModelName(raw);
        if (normalized == null || normalized.isBlank()) {
            return false;
        }
        for (Map.Entry<String, Integer> entry : windowTokens.entrySet()) {
            if (entry == null || entry.getKey() == null) {
                continue;
            }
            Integer tokens = entry.getValue();
            if (tokens == null || tokens <= 0) {
                continue;
            }
            String keyNorm = normalizeModelName(entry.getKey());
            if (normalized.equals(keyNorm)) {
                return true;
            }
        }
        return false;
    }

    private String normalizeModelName(String modelName) {
        if (modelName == null) {
            return null;
        }
        String trimmed = modelName.trim();
        if (trimmed.isEmpty()) {
            return null;
        }

        String candidate = trimmed;
        int slash = candidate.lastIndexOf('/');
        if (slash >= 0 && slash + 1 < candidate.length()) {
            candidate = candidate.substring(slash + 1);
        }
        int colon = candidate.lastIndexOf(':');
        if (colon >= 0 && colon + 1 < candidate.length()) {
            candidate = candidate.substring(colon + 1);
        }
        return candidate.toLowerCase();
    }

    private Map<String, Integer> resolveWindowTokensFromProviders(AiProvidersProperties providers) {
        if (providers == null || providers.configs() == null || providers.configs().isEmpty()) {
            return Map.of();
        }

        Map<String, Integer> map = new HashMap<>();
        for (AiProvidersProperties.ProviderConfig config : providers.configs().values()) {
            if (config == null) {
                continue;
            }
            String model = config.model();
            int tokens = config.windowTokens();
            if (model == null || model.isBlank() || tokens <= 0) {
                continue;
            }
            map.put(model.trim(), tokens);
        }
        return map;
    }

    private ToolCallback[] wrapToolCallbacks(List<ToolCallback> callbacks,
                                             AiObservabilityProperties observabilityProperties,
                                             String modelName) {
        List<ToolCallback> result = new ArrayList<>(callbacks.size());
        boolean enabled = observabilityProperties.tool().enabled();
        for (ToolCallback callback : callbacks) {
            if (callback == null) {
                continue;
            }
            if (!enabled) {
                result.add(callback);
                continue;
            }
            result.add(new ObservedToolCallback(
                    callback,
                    modelName,
                    observabilityProperties.tool().logFullPayload(),
                    observabilityProperties.tool().maxPayloadLength(),
                    observabilityProperties.tool().logToolContext()
            ));
        }
        return result.toArray(new ToolCallback[0]);
    }

    private Map<String, Integer> parseModelWindowOverrides(String overrides) {
        if (overrides == null || overrides.isBlank()) {
            return Map.of();
        }

        // 格式：deepseek-chat:64000,deepseek-reasoner:64000
        Map<String, Integer> map = new HashMap<>();
        String[] pairs = overrides.split(",");
        for (String pair : pairs) {
            if (pair == null || pair.isBlank()) {
                continue;
            }
            String[] parts = pair.trim().split(":");
            if (parts.length != 2) {
                continue;
            }
            String key = parts[0].trim();
            String value = parts[1].trim();
            if (key.isEmpty() || value.isEmpty()) {
                continue;
            }
            try {
                int tokens = Integer.parseInt(value);
                if (tokens > 0) {
                    map.put(key, tokens);
                }
            } catch (NumberFormatException ignored) {
            }
        }
        return map;
    }
}
