package com.doublez.pocketmindserver.ai.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.HashMap;
import java.util.Map;

/**
 * 多厂商/多角色 AI Provider 配置。
 * 说明：
 * - 统一用 OpenAI Compatible API（base-url + api-key + model）。
 * - 通过 routes 将不同业务场景路由到不同 provider。
 */
@ConfigurationProperties(prefix = "pocketmind.ai.providers")
public record AiProvidersProperties(
        String activeChat,
        String activeVision,

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
            String primary,
            String secondary,
            String fallback,
            String vision,
            /**
             * vision 专用降级链路（可选）：当 vision 失败时使用的“第二候选”。
             */
            String visionSecondary,

            /**
             * vision 专用降级链路（可选）：当 vision 与 visionSecondary 都失败时使用的兜底。
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
             * 说明：用于工具结果剪枝/上下文工程等场景；<=0 表示未配置。
             */
            int windowTokens
    ) {
    }

    public ProviderConfig resolveConfigByProviderKey(String providerKey, String purpose) {
        if (providerKey == null || providerKey.isBlank()) {
            throw new IllegalStateException("未配置 providerKey: purpose=" + purpose);
        }
        ProviderConfig config = configs.get(providerKey.trim());
        if (config == null) {
            throw new IllegalStateException("未找到 provider 配置：providerKey=" + providerKey + ", purpose=" + purpose);
        }
        validateConfig(config, providerKey.trim(), purpose);
        return config;
    }

    public String resolveProviderKey(AiRole role) {
        String byRoute = routes == null ? null : switch (role) {
            case PRIMARY -> routes.primary();
            case SECONDARY -> routes.secondary();
            case FALLBACK -> routes.fallback();
            case VISION -> routes.vision();
            case IMAGE -> routes.image();
            case AUDIO -> routes.audio();
        };

        if (byRoute != null && !byRoute.isBlank()) {
            return byRoute.trim();
        }

        // 兼容：如果没有 routes，则沿用 activeChat / activeVision。
        if (role == AiRole.VISION) {
            if (activeVision != null && !activeVision.isBlank()) {
                return activeVision.trim();
            }
        }

        if (activeChat != null && !activeChat.isBlank()) {
            return activeChat.trim();
        }

        return "";
    }

    public ProviderConfig resolveConfig(AiRole role) {
        String providerKey = resolveProviderKey(role);
        if (providerKey.isBlank()) {
            throw new IllegalStateException("未配置 provider 路由：role=" + role);
        }

        ProviderConfig config = configs.get(providerKey);
        if (config == null) {
            throw new IllegalStateException("未找到 provider 配置：providerKey=" + providerKey + ", role=" + role);
        }
        validateConfig(config, providerKey, "role=" + role);
        return config;
    }

    private void validateConfig(ProviderConfig config, String providerKey, String purpose) {
        if (config.baseUrl() == null || config.baseUrl().isBlank()) {
            throw new IllegalStateException("provider.base-url 不能为空：providerKey=" + providerKey + ", " + purpose);
        }
        if (config.apiKey() == null || config.apiKey().isBlank()) {
            throw new IllegalStateException("provider.api-key 不能为空：providerKey=" + providerKey + ", " + purpose);
        }
        if (config.model() == null || config.model().isBlank()) {
            throw new IllegalStateException("provider.model 不能为空：providerKey=" + providerKey + ", " + purpose);
        }
    }
}
