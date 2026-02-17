package com.doublez.pocketmindserver.ai.config;

/**
 * AI 模型角色。
 */
public enum AiRole {
    /**
     * 主 LLM：更贵、更聪明。
     */
    PRIMARY,

    /**
     * 副 LLM：便宜但相对“笨”。
     */
    SECONDARY,

    /**
     * 兜底 LLM：用于主/副失败时降级。
     */
    FALLBACK,

    /**
     * 视觉理解 LLM。
     */
    VISION,

    /**
     * 图片生成 LLM。
     */
    IMAGE,

    /**
     * 音频相关 LLM。
     */
    AUDIO
}
