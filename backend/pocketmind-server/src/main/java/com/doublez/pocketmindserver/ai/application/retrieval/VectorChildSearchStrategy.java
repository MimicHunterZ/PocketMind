package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.ai.application.embedding.EmbeddingService;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository.ScoredCatalogEntry;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 基于 pgvector 余弦相似度的子节点搜索策略。
 *
 * <p>替代关键词匹配的 DbChildSearchStrategy，使用 DashScope text-embedding-v3
 * 生成查询向量，通过 HNSW 索引在 context_catalog 表内完成语义搜索。
 */
@Slf4j
@Component
public class VectorChildSearchStrategy implements ChildSearchStrategy {

    private final EmbeddingService embeddingService;
    private final ContextCatalogRepository catalogRepository;

    public VectorChildSearchStrategy(EmbeddingService embeddingService,
                                     ContextCatalogRepository catalogRepository) {
        this.embeddingService = embeddingService;
        this.catalogRepository = catalogRepository;
    }

    @Override
    public List<ScoredNode> searchChildren(ContextUri parentUri, String queryText, long userId, int limit) {
        float[] queryVector = embeddingService.embed(queryText);
        if (queryVector == null) {
            return List.of();
        }

        return catalogRepository.searchChildrenByVector(queryVector, parentUri.value(), userId, limit)
                .stream()
                .map(VectorChildSearchStrategy::toScoredNode)
                .toList();
    }

    @Override
    public List<ScoredNode> globalSearch(String queryText, long userId, ContextType contextType, int limit) {
        float[] queryVector = embeddingService.embed(queryText);
        if (queryVector == null) {
            return List.of();
        }

        return catalogRepository.searchByVector(queryVector, userId, contextType, limit)
                .stream()
                .map(VectorChildSearchStrategy::toScoredNode)
                .toList();
    }

    @Override
    public List<ScoredNode> loadByUris(List<ContextUri> uris, long userId) {
        List<String> uriValues = uris.stream().map(ContextUri::value).toList();
        return catalogRepository.findByUris(uriValues).stream()
                .map(node -> new ScoredNode(node, 0.0))
                .toList();
    }

    private static ScoredNode toScoredNode(ScoredCatalogEntry entry) {
        return new ScoredNode(entry.node(), entry.similarity());
    }
}
