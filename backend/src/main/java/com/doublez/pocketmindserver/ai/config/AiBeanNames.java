package com.doublez.pocketmindserver.ai.config;

/**
 * AI 相关 Bean 名称常量。
 */
public final class AiBeanNames {

    private AiBeanNames() {
    }

    public static final String CHAT_PRIMARY_MODEL = "chatPrimaryChatModel";
    public static final String CHAT_SECONDARY_MODEL = "chatSecondaryChatModel";
    public static final String CHAT_FALLBACK_MODEL = "chatFallbackChatModel";

    public static final String VISION_PRIMARY_MODEL = "visionPrimaryChatModel";
    public static final String VISION_SECONDARY_MODEL = "visionSecondaryChatModel";
    public static final String VISION_FALLBACK_MODEL = "visionFallbackChatModel";

    public static final String IMAGE_MODEL = "imageChatModel";
    public static final String AUDIO_MODEL = "audioChatModel";

    public static final String CHAT_PRIMARY_CLIENT = "chatPrimaryChatClient";
    public static final String CHAT_SECONDARY_CLIENT = "chatSecondaryChatClient";
    public static final String CHAT_FALLBACK_CLIENT = "chatFallbackChatClient";

    public static final String VISION_PRIMARY_CLIENT = "visionPrimaryChatClient";
    public static final String VISION_SECONDARY_CLIENT = "visionSecondaryChatClient";
    public static final String VISION_FALLBACK_CLIENT = "visionFallbackChatClient";

    public static final String IMAGE_CLIENT = "imageChatClient";
    public static final String AUDIO_CLIENT = "audioChatClient";
}
