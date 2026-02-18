package com.doublez.pocketmindserver.ai.observability;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * AI 可观测性相关配置。
 */
@ConfigurationProperties(prefix = "pocketmind.ai.observability")
public record AiObservabilityProperties(
        Langfuse langfuse,
        Chat chat,
        Tool tool
) {

    public AiObservabilityProperties {
        if (langfuse == null) {
            langfuse = new Langfuse(false, false, false, 4000);
        }
        if (chat == null) {
            chat = new Chat(false);
        }
        if (tool == null) {
            tool = new Tool(false, false, 1200, false);
        }
    }

    /**
     * Langfuse OTel 展示适配。
     */
    public record Langfuse(
            boolean enabled,

            /**
             * 是否捕获 HTTP 请求/响应 body（写入 langfuse.observation.input/output）。
             *
             * 注意：该能力可能暴露敏感信息，建议仅在开发/排障环境开启。
             */
            boolean httpBodyCaptureEnabled,

            /**
             * 是否记录完整 payload。
             */
            boolean logFullPayload,

            /**
             * payload 最大长度（字符数），超出后截断。
             */
            int maxPayloadLength
    ) {
    }

    /**
     * ChatClient 层面的调试 Advisor。
     */
    public record Chat(
            boolean simpleLoggerEnabled
    ) {
    }

    /**
     * 工具调用观测 用于工具调用场景的日志与 Langfuse observation 字段补齐。
     */
    public record Tool(
            boolean enabled,
            boolean logFullPayload,
            int maxPayloadLength,
            boolean logToolContext
    ) {
    }
}
