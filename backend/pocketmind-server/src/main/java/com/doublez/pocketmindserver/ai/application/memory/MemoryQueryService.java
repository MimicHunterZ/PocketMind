package com.doublez.pocketmindserver.ai.application.memory;

import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;

import java.util.List;

/**
 * 聊天长期记忆查询服务。
 */
public interface MemoryQueryService {

    /**
     * 查询当前聊天请求相关的记忆条目。
     */
    List<MemoryRecordEntity> queryRelevantMemories(long userId, ChatSessionEntity session, String userPrompt);

    /**
     * 按类型查询用户记忆（例如用于提取系统的核心级 L0 记忆）
     */
    List<MemoryRecordEntity> queryMemoriesByType(long userId, com.doublez.pocketmindserver.memory.domain.MemoryType memoryType, int limit);
}
