package com.doublez.pocketmindserver.ai.config;

import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.HashMap;
import java.util.Map;

/**
 * 多厂商、多角色 AI Provider 配置。
 * 说明：
 * - 统一使用 OpenAI Compatible API（base-url + api-key + model）。
 * - 通过 routes 将不同业务场景路由到不同 provider。
 */
@ConfigurationProperties(prefix = "pocketmind.ai.providers")
public record AiProvidersProperties(
        Routes routes,
        Map<String, ProviderConfig> configs
) {

    public AiProvidersProperties {
        if (configs == null) {
            configs = new HashMap<>();
        }
    }

    /**
         * 角色路由：每个角色指定一个 provider key（对应 configs 的 key）。
     */
    public record Routes(
            /**
             * 对话主模型路由（chat-primary）。
             */
            String chatPrimary,

            /**
             * 对话次模型路由（chat-secondary）。
             */
            String chatSecondary,

            /**
             * 对话兜底模型路由（chat-fallback）。
             */
            String chatFallback,

            /**
             * 视觉主模型路由（vision-primary）。
             */
            String visionPrimary,

            /**
             * vision 专用降级链路（可选）：当 vision 失败时使用的“第二候选”。
             */
            String visionSecondary,

            /**
             * vision 专用降级链路（可选）：当 vision 和 visionSecondary 都失败时使用的兜底。
             */
            String visionFallback,
            String image,
            String audio
    ) {
    }

    /**
        * OpenAI Compatible 配置。
     */
    public record ProviderConfig(
            String apiKey,
            String baseUrl,
            String model,

            /**
                 * 模型最大上下文窗口。
             *
                 * 说明：用于工具结果剪枝、上下文工程等场景。<=0 表示未配置。
             */
            int windowTokens
    ) {
    }

    public String resolveProviderKey(AiClientId clientId) {
        String byRoute = routes == null ? null : switch (clientId) {
            case CHAT_PRIMARY -> routes.chatPrimary();
            case CHAT_SECONDARY -> routes.chatSecondary();
            case CHAT_FALLBACK -> routes.chatFallback();
            case VISION_PRIMARY -> routes.visionPrimary();
            case VISION_SECONDARY -> routes.visionSecondary();
            case VISION_FALLBACK -> routes.visionFallback();
            case IMAGE -> routes.image();
            case AUDIO -> routes.audio();
        };

        if (byRoute != null && !byRoute.isBlank()) {
            return byRoute.trim();
        }
        return "";
    }

    public ProviderConfig resolveConfig(AiClientId clientId) {
        String providerKey = resolveProviderKey(clientId);
        if (providerKey.isBlank()) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "未配置 provider 路由，clientId=" + clientId);
        }

        ProviderConfig config = configs.get(providerKey);
        if (config == null) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "未找到 provider 配置：providerKey=" + providerKey + ", clientId=" + clientId);
        }
        validateConfig(config, providerKey, "clientId=" + clientId);
        return config;
    }

    private void validateConfig(ProviderConfig config, String providerKey, String purpose) {
        if (config.baseUrl() == null || config.baseUrl().isBlank()) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "provider.base-url 不能为空：providerKey=" + providerKey + ", " + purpose);
        }
        if (config.apiKey() == null || config.apiKey().isBlank()) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "provider.api-key 不能为空：providerKey=" + providerKey + ", " + purpose);
        }
        if (config.model() == null || config.model().isBlank()) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "provider.model 不能为空：providerKey=" + providerKey + ", " + purpose);
        }
    }
}

