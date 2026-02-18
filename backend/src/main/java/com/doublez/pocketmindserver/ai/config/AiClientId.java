package com.doublez.pocketmindserver.ai.config;

import lombok.Getter;

/**
 * ChatClient 枚举
 */
@Getter
public enum AiClientId {
    CHAT_PRIMARY(true, false),
    CHAT_SECONDARY(true, false),
    CHAT_FALLBACK(true, false),

    VISION_PRIMARY(false, true),
    VISION_SECONDARY(false, true),
    VISION_FALLBACK(false, true),

    IMAGE(false, false),
    AUDIO(false, false);

    private final boolean chat;
    private final boolean vision;

    AiClientId(boolean chat, boolean vision) {
        this.chat = chat;
        this.vision = vision;
    }

}
