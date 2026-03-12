package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.ai.application.embedding.EmbeddingService;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository.ScoredMemoryEntry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 基于 pgvector 余弦相似度的记忆检索器。
 *
 * <p>将查询文本向量化后，在 memory_records 表中通过 HNSW 索引检索最相关的记忆，
 * 同时递增命中记忆的 activeCount（热度追踪）。
 */
@Slf4j
@Component
public class VectorMemoryRetriever implements MemoryRetriever {

    private final EmbeddingService embeddingService;
    private final MemoryRecordRepository memoryRecordRepository;

    public VectorMemoryRetriever(EmbeddingService embeddingService,
                                 MemoryRecordRepository memoryRecordRepository) {
        this.embeddingService = embeddingService;
        this.memoryRecordRepository = memoryRecordRepository;
    }

    @Override
    public List<ContextSnippet> retrieve(String queryText, long userId, int limit) {
        float[] queryVector = embeddingService.embed(queryText);
        if (queryVector == null) {
            return List.of();
        }

        List<ScoredMemoryEntry> entries = memoryRecordRepository.searchByVector(queryVector, userId, limit);
        if (entries.isEmpty()) {
            return List.of();
        }

        List<ContextSnippet> snippets = entries.stream()
                .map(VectorMemoryRetriever::toSnippet)
                .toList();

        // 批量递增热度
        entries.forEach(e -> memoryRecordRepository.incrementActiveCount(e.entity().getUuid()));

        log.debug("[vector-memory-retriever] 检索到 {} 条记忆: userId={}", snippets.size(), userId);
        return snippets;
    }

    private static ContextSnippet toSnippet(ScoredMemoryEntry entry) {
        MemoryRecordEntity m = entry.entity();
        return new ContextSnippet(
                m.getRootUri() != null ? m.getRootUri().value() : "pm://memories/" + m.getUuid(),
                m.getTitle(),
                m.getAbstractText(),
                m.getContent(),
                entry.similarity(),
                SnippetSource.MEMORY
        );
    }
}
