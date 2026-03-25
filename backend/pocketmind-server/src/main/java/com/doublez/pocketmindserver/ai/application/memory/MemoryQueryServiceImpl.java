package com.doublez.pocketmindserver.ai.application.memory;

import com.doublez.pocketmindserver.ai.application.embedding.EmbeddingService;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.memory.application.MemoryContextService;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * 长期记忆查询实现 — 从 memory_records 检索与当前对话相关的记忆，组装为上下文文本。
 *
 * <p>检索策略：向量检索优先，关键词检索回退。
 */
@Slf4j
@Service
public class MemoryQueryServiceImpl implements MemoryQueryService {

    private static final int MAX_MEMORY_RESULTS = 8;

    private final EmbeddingService embeddingService;
    private final MemoryContextService memoryContextService;
    private final MemoryRecordRepository memoryRecordRepository;

    public MemoryQueryServiceImpl(EmbeddingService embeddingService,
                                  MemoryContextService memoryContextService,
                                  MemoryRecordRepository memoryRecordRepository) {
        this.embeddingService = embeddingService;
        this.memoryContextService = memoryContextService;
        this.memoryRecordRepository = memoryRecordRepository;
    }

    @Override
    public List<MemoryRecordEntity> queryMemoriesByType(long userId, com.doublez.pocketmindserver.memory.domain.MemoryType memoryType, int limit) {
        return memoryRecordRepository.findByUserIdAndType(userId, memoryType, limit);
    }

    @Override
    public List<MemoryRecordEntity> queryRelevantMemories(long userId, ChatSessionEntity session, String userPrompt) {
        log.debug("[memory] 查询用户记忆: userId={}, sessionUuid={}, memoryRoot={}",
                userId,
                session.getUuid(),
                memoryContextService.userMemoryRoot(userId));

        List<MemoryRecordEntity> vectorOrFallbackMemories = searchRelevantMemories(userId, userPrompt);
        if (vectorOrFallbackMemories.isEmpty()) {
            log.debug("[memory] 未找到相关记忆: userId={}", userId);
        }
        vectorOrFallbackMemories.forEach(m -> memoryRecordRepository.incrementActiveCount(m.getUuid(), userId));
        log.info("[memory] 检索到 {} 条相关记忆: userId={}", vectorOrFallbackMemories.size(), userId);
        return vectorOrFallbackMemories;
    }

    private List<MemoryRecordEntity> searchRelevantMemories(long userId, String userPrompt) {
        if (userPrompt == null || userPrompt.isBlank()) {
            return memoryRecordRepository.searchByKeyword(userId, null, null, MAX_MEMORY_RESULTS);
        }

        float[] queryVector = embeddingService.embed(userPrompt);
        if (queryVector != null) {
            List<MemoryRecordRepository.ScoredMemoryEntry> vectorHits =
                    memoryRecordRepository.searchByVector(queryVector, userId, MAX_MEMORY_RESULTS);
            if (!vectorHits.isEmpty()) {
                return vectorHits.stream()
                        .map(MemoryRecordRepository.ScoredMemoryEntry::entity)
                        .toList();
            }
        }

        log.debug("[memory] 向量未命中，回退关键词检索: userId={}", userId);
        return memoryRecordRepository.searchByKeyword(userId, userPrompt, null, MAX_MEMORY_RESULTS);
    }
}
