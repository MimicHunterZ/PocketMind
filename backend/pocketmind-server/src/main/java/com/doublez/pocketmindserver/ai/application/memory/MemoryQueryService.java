package com.doublez.pocketmindserver.ai.application.memory;

import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;

/**
 * 聊天长期记忆查询服务。
 */
public interface MemoryQueryService {

    /**
     * 为当前聊天请求构建可注入的长期记忆上下文块。
     */
    String buildMemoryContext(long userId, ChatSessionEntity session, String userPrompt);
}
