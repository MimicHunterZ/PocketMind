package com.doublez.pocketmindserver.ai.config;

import com.doublez.pocketmindserver.ai.context.PersistingPruningToolCallAdvisor;
import com.doublez.pocketmindserver.ai.context.PersistingToolCallAdvisor;
import com.doublez.pocketmindserver.ai.context.ToolResultContextEngineeringProperties;
import com.doublez.pocketmindserver.ai.context.TrustedModelContextWindowResolver;
import com.doublez.pocketmindserver.ai.observability.AiObservabilityProperties;
import com.doublez.pocketmindserver.ai.observability.langfuse.LangfuseChatObservationAdvisor;
import com.doublez.pocketmindserver.ai.observability.langfuse.AiLangfuseHttpBodyCaptureInterceptor;
import com.doublez.pocketmindserver.ai.observability.tool.ObservedToolCallback;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import io.micrometer.observation.ObservationRegistry;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.SimpleLoggerAdvisor;
import org.springframework.ai.chat.client.advisor.ToolCallAdvisor;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.OpenAiEmbeddingModel;
import org.springframework.ai.openai.OpenAiEmbeddingOptions;
import org.springframework.ai.document.MetadataMode;
import org.springframework.ai.model.tool.ToolCallingManager;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.retry.RetryTemplate;
import org.springframework.http.HttpStatus;
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

    private final ChatMessageRepository chatMessageRepository;
    private final ObjectMapper objectMapper;

    public AiConfiguration(ChatMessageRepository chatMessageRepository, ObjectMapper objectMapper) {
        this.chatMessageRepository = chatMessageRepository;
        this.objectMapper = objectMapper;
    }

    /**
        * 启动期校验：vision 的降级链路必须成对配置。
     */
    @Bean
    public SmartInitializingSingleton aiProvidersStartupValidator(AiProvidersProperties providers) {
        return () -> {
            validateChatFailoverRoutes(providers);
            validateVisionFailoverRoutes(providers);
        };
    }

    private void validateChatFailoverRoutes(AiProvidersProperties providers) {
        if (providers == null || providers.routes() == null) {
            return;
        }

        boolean hasChatPrimary = StringUtils.hasText(providers.routes().chatPrimary());
        if (!hasChatPrimary) {
            throw new BusinessException(
                    ApiCode.INTERNAL_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "必须配置 " + AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX + "." + AiProviderRouteKeys.CHAT_PRIMARY
            );
        }

        String chatSecondary = providers.routes().chatSecondary();
        String chatFallback = providers.routes().chatFallback();

        boolean hasChatSecondary = StringUtils.hasText(chatSecondary);
        boolean hasChatFallback = StringUtils.hasText(chatFallback);

        // chat 链路：允许只配置 secondary（主 -> 次），不强制要求 fallback。
        if (!hasChatSecondary && hasChatFallback) {
            throw new BusinessException(
                    ApiCode.INTERNAL_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                "chat-fallback 不能单独配置：请同时配置 chat-secondary，或仅配置 chat-secondary"
            );
        }

        // 若配置了链路，则确保 config 合法。
        if (hasChatSecondary) {
            providers.resolveConfig(AiClientId.CHAT_SECONDARY);
            if (hasChatFallback) {
                providers.resolveConfig(AiClientId.CHAT_FALLBACK);
            }
        }
    }

    private void validateVisionFailoverRoutes(AiProvidersProperties providers) {
        if (providers == null || providers.routes() == null) {
            return;
        }

        boolean hasVisionPrimary = StringUtils.hasText(providers.routes().visionPrimary());
        if (!hasVisionPrimary) {
            throw new BusinessException(
                    ApiCode.INTERNAL_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "必须配置 " + AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX + "." + AiProviderRouteKeys.VISION_PRIMARY
            );
        }

        String visionSecondary = providers.routes().visionSecondary();
        String visionFallback = providers.routes().visionFallback();

        boolean hasVisionSecondary = StringUtils.hasText(visionSecondary);
        boolean hasVisionFallback = StringUtils.hasText(visionFallback);

        // vision 链路：允许只配置 secondary（主 -> 次），不强制要求 fallback。
        if (!hasVisionSecondary && hasVisionFallback) {
            throw new BusinessException(
                    ApiCode.INTERNAL_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                AiProviderRouteKeys.VISION_FALLBACK + " 不能单独配置：请同时配置 " + AiProviderRouteKeys.VISION_SECONDARY + "，或仅配置 " + AiProviderRouteKeys.VISION_SECONDARY
            );
        }

        // 若配置了链路，则确保 providerKey 存在且 config 合法。
        if (hasVisionSecondary) {
            providers.resolveConfig(AiClientId.VISION_SECONDARY);
            if (hasVisionFallback) {
                providers.resolveConfig(AiClientId.VISION_FALLBACK);
            }
        }
    }

    // region ChatModel

    @Bean(AiBeanNames.CHAT_PRIMARY_MODEL)
    public OpenAiChatModel primaryChatModel(AiProvidersProperties providers,
                                            AiHttpClientProperties httpClientProperties,
                                            AiObservabilityProperties observabilityProperties,
                                            ObservationRegistry observationRegistry,
                                            RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiClientId.CHAT_PRIMARY), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean(AiBeanNames.CHAT_SECONDARY_MODEL)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.CHAT_SECONDARY)
    public OpenAiChatModel secondaryChatModel(AiProvidersProperties providers,
                                              AiHttpClientProperties httpClientProperties,
                                              AiObservabilityProperties observabilityProperties,
                                              ObservationRegistry observationRegistry,
                                              RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiClientId.CHAT_SECONDARY), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean(AiBeanNames.CHAT_FALLBACK_MODEL)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.CHAT_FALLBACK)
    public OpenAiChatModel fallbackChatModel(AiProvidersProperties providers,
                                             AiHttpClientProperties httpClientProperties,
                                             AiObservabilityProperties observabilityProperties,
                                             ObservationRegistry observationRegistry,
                                             RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiClientId.CHAT_FALLBACK), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean(AiBeanNames.VISION_PRIMARY_MODEL)
    public OpenAiChatModel visionChatModel(AiProvidersProperties providers,
                                           AiHttpClientProperties httpClientProperties,
                                           AiObservabilityProperties observabilityProperties,
                                           ObservationRegistry observationRegistry,
                                           RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiClientId.VISION_PRIMARY), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    // region Vision failover chain (optional)

    @Bean(AiBeanNames.VISION_SECONDARY_MODEL)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.VISION_SECONDARY)
    public OpenAiChatModel visionSecondaryChatModel(AiProvidersProperties providers,
                                                    AiHttpClientProperties httpClientProperties,
                                                    AiObservabilityProperties observabilityProperties,
                                                    ObservationRegistry observationRegistry,
                                                    RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiClientId.VISION_SECONDARY), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean(AiBeanNames.VISION_FALLBACK_MODEL)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.VISION_FALLBACK)
    public OpenAiChatModel visionFallbackChatModel(AiProvidersProperties providers,
                                                   AiHttpClientProperties httpClientProperties,
                                                   AiObservabilityProperties observabilityProperties,
                                                   ObservationRegistry observationRegistry,
                                                   RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiClientId.VISION_FALLBACK), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean(AiBeanNames.IMAGE_MODEL)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.IMAGE)
    public OpenAiChatModel imageChatModel(AiProvidersProperties providers,
                                          AiHttpClientProperties httpClientProperties,
                                          AiObservabilityProperties observabilityProperties,
                                          ObservationRegistry observationRegistry,
                                          RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiClientId.IMAGE), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    @Bean(AiBeanNames.AUDIO_MODEL)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.AUDIO)
    public OpenAiChatModel audioChatModel(AiProvidersProperties providers,
                                          AiHttpClientProperties httpClientProperties,
                                          AiObservabilityProperties observabilityProperties,
                                          ObservationRegistry observationRegistry,
                                          RetryTemplate retryTemplate) {
        return buildChatModel(providers.resolveConfig(AiClientId.AUDIO), httpClientProperties, observabilityProperties, observationRegistry, retryTemplate);
    }

    private OpenAiChatModel buildChatModel(AiProvidersProperties.ProviderConfig config,
                                           AiHttpClientProperties httpClientProperties,
                                           AiObservabilityProperties observabilityProperties,
                                           ObservationRegistry observationRegistry,
                                           RetryTemplate retryTemplate) {
        Objects.requireNonNull(config, "config");

        // 使用阻塞 requestFactory 显式控制超时，避免 Reactor Netty 默认超时导致 ReadTimeout。
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

    // region ChatClient（多角色）

    // region EmbeddingModel

    @Bean(AiBeanNames.EMBEDDING_MODEL)
    @ConditionalOnProperty(prefix = "pocketmind.ai.embedding", name = "provider")
    public OpenAiEmbeddingModel embeddingModel(AiProvidersProperties providers,
                                               EmbeddingProperties embeddingProperties,
                                               AiHttpClientProperties httpClientProperties,
                                               ObservationRegistry observationRegistry,
                                               RetryTemplate retryTemplate) {
        AiProvidersProperties.ProviderConfig providerCfg = providers.configs().get(embeddingProperties.provider());
        Objects.requireNonNull(providerCfg,
                "embedding.provider='" + embeddingProperties.provider() + "' 在 providers.configs 中不存在");

        SimpleClientHttpRequestFactory baseFactory = new SimpleClientHttpRequestFactory();
        baseFactory.setConnectTimeout(httpClientProperties.connectTimeoutMs());
        baseFactory.setReadTimeout(httpClientProperties.readTimeoutMs());

        OpenAiApi api = OpenAiApi.builder()
                .baseUrl(providerCfg.baseUrl())
                .apiKey(providerCfg.apiKey())
                .restClientBuilder(RestClient.builder()
                        .requestFactory(new BufferingClientHttpRequestFactory(baseFactory)))
                .build();

        return new OpenAiEmbeddingModel(
                api,
                MetadataMode.EMBED,
                OpenAiEmbeddingOptions.builder()
                        .model(embeddingProperties.model())
                        .dimensions(embeddingProperties.dimensions())
                        .build(),
                retryTemplate,
                observationRegistry
        );
    }

    // endregion

    // region ChatClient（多角色）

    @Bean(AiBeanNames.CHAT_PRIMARY_CLIENT)
    public ChatClient primaryChatClient(@Qualifier(AiBeanNames.CHAT_PRIMARY_MODEL) OpenAiChatModel primaryChatModel,
                                        AiProvidersProperties providers,
                                        JsonMapper aiJsonMapper,
                                        AiObservabilityProperties observabilityProperties,
                                        ToolResultContextEngineeringProperties toolResultProps,
                                        List<ToolCallback> toolCallbacks) {
        return buildChatClient(AiClientId.CHAT_PRIMARY, primaryChatModel, providers, providers.resolveConfig(AiClientId.CHAT_PRIMARY).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean(AiBeanNames.CHAT_SECONDARY_CLIENT)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.CHAT_SECONDARY)
    public ChatClient secondaryChatClient(@Qualifier(AiBeanNames.CHAT_SECONDARY_MODEL) OpenAiChatModel secondaryChatModel,
                                          AiProvidersProperties providers,
                                          JsonMapper aiJsonMapper,
                                          AiObservabilityProperties observabilityProperties,
                                          ToolResultContextEngineeringProperties toolResultProps,
                                          List<ToolCallback> toolCallbacks) {
        return buildChatClient(AiClientId.CHAT_SECONDARY, secondaryChatModel, providers, providers.resolveConfig(AiClientId.CHAT_SECONDARY).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean(AiBeanNames.CHAT_FALLBACK_CLIENT)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.CHAT_FALLBACK)
    public ChatClient fallbackChatClient(@Qualifier(AiBeanNames.CHAT_FALLBACK_MODEL) OpenAiChatModel fallbackChatModel,
                                         AiProvidersProperties providers,
                                         JsonMapper aiJsonMapper,
                                         AiObservabilityProperties observabilityProperties,
                                         ToolResultContextEngineeringProperties toolResultProps,
                                         List<ToolCallback> toolCallbacks) {
        return buildChatClient(AiClientId.CHAT_FALLBACK, fallbackChatModel, providers, providers.resolveConfig(AiClientId.CHAT_FALLBACK).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean(AiBeanNames.VISION_PRIMARY_CLIENT)
    public ChatClient visionChatClient(@Qualifier(AiBeanNames.VISION_PRIMARY_MODEL) OpenAiChatModel visionChatModel,
                                       AiProvidersProperties providers,
                                       JsonMapper aiJsonMapper,
                                       AiObservabilityProperties observabilityProperties,
                                       ToolResultContextEngineeringProperties toolResultProps,
                                       List<ToolCallback> toolCallbacks) {
        return buildChatClient(AiClientId.VISION_PRIMARY, visionChatModel, providers, providers.resolveConfig(AiClientId.VISION_PRIMARY).model(), aiJsonMapper,
                observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean(AiBeanNames.VISION_SECONDARY_CLIENT)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.VISION_SECONDARY)
        public ChatClient visionSecondaryChatClient(@Qualifier(AiBeanNames.VISION_SECONDARY_MODEL) OpenAiChatModel visionSecondaryModel,
                                                AiProvidersProperties providers,
                                                JsonMapper aiJsonMapper,
                                                AiObservabilityProperties observabilityProperties,
                                                ToolResultContextEngineeringProperties toolResultProps,
                                                List<ToolCallback> toolCallbacks) {
        return buildChatClient(AiClientId.VISION_SECONDARY, visionSecondaryModel, providers, providers.resolveConfig(AiClientId.VISION_SECONDARY).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean(AiBeanNames.VISION_FALLBACK_CLIENT)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.VISION_FALLBACK)
    public ChatClient visionFallbackChatClient(@Qualifier(AiBeanNames.VISION_FALLBACK_MODEL) OpenAiChatModel chatModel,
                                               AiProvidersProperties providers,
                                               JsonMapper aiJsonMapper,
                                               AiObservabilityProperties observabilityProperties,
                                               ToolResultContextEngineeringProperties toolResultProps,
                                               List<ToolCallback> toolCallbacks) {
        return buildChatClient(AiClientId.VISION_FALLBACK, chatModel, providers, providers.resolveConfig(AiClientId.VISION_FALLBACK).model(), aiJsonMapper, observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean(AiBeanNames.IMAGE_CLIENT)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.IMAGE)
    public ChatClient imageChatClient(@Qualifier(AiBeanNames.IMAGE_MODEL) OpenAiChatModel imageChatModel,
                                      AiProvidersProperties providers,
                                      JsonMapper aiJsonMapper,
                                      AiObservabilityProperties observabilityProperties,
                                      ToolResultContextEngineeringProperties toolResultProps,
                                      List<ToolCallback> toolCallbacks) {
        return buildChatClient(AiClientId.IMAGE, imageChatModel, providers, providers.resolveConfig(AiClientId.IMAGE).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    @Bean(AiBeanNames.AUDIO_CLIENT)
    @ConditionalOnProperty(prefix = AiProviderRouteKeys.PROVIDERS_ROUTES_PREFIX, name = AiProviderRouteKeys.AUDIO)
    public ChatClient audioChatClient(@Qualifier(AiBeanNames.AUDIO_MODEL) OpenAiChatModel audioChatModel,
                                      AiProvidersProperties providers,
                                      JsonMapper aiJsonMapper,
                                      AiObservabilityProperties observabilityProperties,
                                      ToolResultContextEngineeringProperties toolResultProps,
                                      List<ToolCallback> toolCallbacks) {
        return buildChatClient(AiClientId.AUDIO, audioChatModel, providers, providers.resolveConfig(AiClientId.AUDIO).model(), aiJsonMapper,
            observabilityProperties, toolResultProps, toolCallbacks);
    }

    private ChatClient buildChatClient(AiClientId clientId,
                                       OpenAiChatModel chatModel,
                                       AiProvidersProperties providers,
                                       String modelName,
                                       JsonMapper aiJsonMapper,
                                       AiObservabilityProperties observabilityProperties,
                                       ToolResultContextEngineeringProperties toolResultContextEngineeringProperties,
                                       List<ToolCallback> toolCallbacks) {
        ChatClient.Builder builder = ChatClient.builder(chatModel);

        List<ToolCallback> selectedToolCallbacks = filterToolCallbacksForClient(clientId, toolCallbacks);

        // 1) Langfuse 展示适配（业务侧独立开关，禁止使用 demo 配置）。
        if (observabilityProperties.langfuse().enabled()) {
            builder.defaultAdvisors(new LangfuseChatObservationAdvisor(aiJsonMapper));
        }

        // 2) 工具调用：默认 tool advisor，以及可选的 tool-result 剪枝。
        //    注意：只有在存在 tool callback 时才挂载 tool advisor，避免无工具场景引入额外复杂度。
        if (!selectedToolCallbacks.isEmpty()) {
            ToolCallAdvisor toolCallAdvisor = buildToolCallAdvisor(providers, toolResultContextEngineeringProperties, modelName);
            builder.defaultAdvisors(toolCallAdvisor);
        }

        // 3) ChatClient 调试日志。
        if (observabilityProperties.chat().simpleLoggerEnabled()) {
            builder.defaultAdvisors(new SimpleLoggerAdvisor());
        }

        // 4) 默认工具回调：如果业务侧注册 ToolCallback，则默认启用（并按开关做观测包装）。
        if (!selectedToolCallbacks.isEmpty()) {
            builder.defaultToolCallbacks(wrapToolCallbacks(selectedToolCallbacks, observabilityProperties, modelName));
        }

        return builder.build();
    }

    private List<ToolCallback> filterToolCallbacksForClient(AiClientId clientId, List<ToolCallback> toolCallbacks) {
        if (toolCallbacks == null || toolCallbacks.isEmpty()) {
            return List.of();
        }
        if (clientId == null) {
            return List.of();
        }

        // 视觉链路不提供工具；对话链路提供 Skills/FileSystem/Shell 三类工具。
        // 当前工程工具来源（AiToolsConfiguration）就是这三类，因此对话侧直接启用全部 ToolCallback 即可。
        if (clientId.isVision()) {
            return List.of();
        }
        if (clientId.isChat()) {
            return toolCallbacks;
        }

        // 其他类型默认不启用工具（如 image/audio）。
        return List.of();
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

            // 强约束：启用剪枝时，必须为当前模型显式配置上下文窗口。
            if (!hasExplicitWindowTokensForModel(windowTokens, modelName)) {
                throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "已开启 pocketmind.context-engineering.tool-result.enabled=true，但未为当前模型配置 window-tokens，model="
                                + (modelName == null ? "" : modelName)
                        + "。请在 pocketmind.ai.providers.configs.*.window-tokens 或 pocketmind.context-engineering.tool-result.model-window-tokens 中显式配置。"
                );
            }

            TrustedModelContextWindowResolver resolver = new TrustedModelContextWindowResolver(
                    props.defaultWindowTokens(),
                    windowTokens
            );
                return new PersistingPruningToolCallAdvisor(
                    ToolCallingManager.builder().build(),
                    props.compressStartRatio(),
                    props.keepRecentToolResponses(),
                    resolver,
                    modelName,
                    chatMessageRepository,
                    objectMapper
                );
        }

            // 榛樿 ToolCallAdvisor + 钀藉簱澧炲己
            return new PersistingToolCallAdvisor(
                ToolCallingManager.builder().build(),
                chatMessageRepository,
                objectMapper
            );
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

}

