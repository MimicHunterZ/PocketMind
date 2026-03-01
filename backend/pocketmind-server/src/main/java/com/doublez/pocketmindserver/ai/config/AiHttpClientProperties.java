package com.doublez.pocketmindserver.ai.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * AI HTTP 客户端相关超时配置。
 * 自建 OpenAiApi 时如果不显式设置超时，容易在“大 prompt/图片 base64”场景触发 ReadTimeout。
 */
@ConfigurationProperties(prefix = "pocketmind.ai.http")
public record AiHttpClientProperties(
        int connectTimeoutMs,
        int readTimeoutMs
) {

    public AiHttpClientProperties {
        if (connectTimeoutMs <= 0) {
            connectTimeoutMs = 30_000;
        }
        if (readTimeoutMs <= 0) {
            // 视觉场景图片转 Base64 后 payload 较大，给更宽松的默认值。
            readTimeoutMs = 180_000;
        }
    }
}
