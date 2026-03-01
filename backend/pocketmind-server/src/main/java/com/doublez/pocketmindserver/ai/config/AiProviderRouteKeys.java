package com.doublez.pocketmindserver.ai.config;

/**
 * AI Provider routes 的配置键名常量。
 *
 * 说明：
 * - 用于 @ConditionalOnProperty、启动期校验、配置解析等，避免硬编码字符串。
 */
public final class AiProviderRouteKeys {

    private AiProviderRouteKeys() {
    }

    public static final String PROVIDERS_ROUTES_PREFIX = "pocketmind.ai.providers.routes";

    public static final String CHAT_PRIMARY = "chat-primary";
    public static final String CHAT_SECONDARY = "chat-secondary";
    public static final String CHAT_FALLBACK = "chat-fallback";

    public static final String VISION_PRIMARY = "vision-primary";
    public static final String VISION_SECONDARY = "vision-secondary";
    public static final String VISION_FALLBACK = "vision-fallback";

    public static final String IMAGE = "image";
    public static final String AUDIO = "audio";
}
