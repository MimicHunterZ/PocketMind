package com.doublez.pocketmindserver.ai.application.memory;

import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * 全量记忆注入器。
 *
 * <p>用于在系统提示词中注入用户长期记忆的 L0 摘要，
 * 与查询时的命中记忆形成互补：
 * <ul>
 *   <li>命中记忆：高相关、少量片段</li>
 *   <li>全量记忆：稳定偏好与长期画像</li>
 * </ul>
 */
@Slf4j
@Service
public class MemoryInjector {

    private static final int DEFAULT_INJECTION_LIMIT = 30;

    private final MemoryRecordRepository memoryRecordRepository;

    public MemoryInjector(MemoryRecordRepository memoryRecordRepository) {
        this.memoryRecordRepository = memoryRecordRepository;
    }

    /**
     * 查询用于系统提示词注入的全量记忆（仅负责数据检索）。
     */
    public List<MemoryRecordEntity> queryAllMemories(long userId) {
        return queryAllMemories(userId, DEFAULT_INJECTION_LIMIT);
    }

    /**
     * 查询用于系统提示词注入的全量记忆（仅负责数据检索）。
     */
    public List<MemoryRecordEntity> queryAllMemories(long userId, int limit) {
        List<MemoryRecordEntity> memories = memoryRecordRepository.findActiveByUserId(userId, limit);
        log.debug("[memory-injector] 查询全量记忆: userId={}, count={}", userId, memories.size());
        return memories;
    }
}
