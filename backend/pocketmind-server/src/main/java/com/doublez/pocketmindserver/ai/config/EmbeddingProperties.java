package com.doublez.pocketmindserver.ai.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 向量嵌入模型配置。
 *
 * @param provider   复用 providers.configs 中的 provider key（获取 base-url、api-key）
 * @param model      嵌入模型名称（如 text-embedding-v3）
 * @param dimensions 向量维度
 */
@ConfigurationProperties(prefix = "pocketmind.ai.embedding")
public record EmbeddingProperties(
        String provider,
        String model,
        int dimensions
) {
    public EmbeddingProperties {
        if (dimensions <= 0) dimensions = 1024;
    }
}
