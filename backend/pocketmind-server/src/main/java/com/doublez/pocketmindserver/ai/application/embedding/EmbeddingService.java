package com.doublez.pocketmindserver.ai.application.embedding;

import com.doublez.pocketmindserver.ai.config.AiBeanNames;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

/**
 * 向量嵌入服务 — 将文本转换为 float[] 向量。
 *
 * <p>底层委托给 Spring AI {@link EmbeddingModel}（DashScope text-embedding-v3, 1024 维）。
 */
@Slf4j
@Service
public class EmbeddingService {

    private final EmbeddingModel embeddingModel;

    public EmbeddingService(@Qualifier(AiBeanNames.EMBEDDING_MODEL) EmbeddingModel embeddingModel) {
        this.embeddingModel = embeddingModel;
    }

    /**
     * 生成文本的向量表示。
     *
     * @param text 输入文本（不得为空或空白）
     * @return 1024 维浮点数组
     */
    public float[] embed(String text) {
        if (text == null || text.isBlank()) {
            return null;
        }
        return embeddingModel.embed(text);
    }
}
