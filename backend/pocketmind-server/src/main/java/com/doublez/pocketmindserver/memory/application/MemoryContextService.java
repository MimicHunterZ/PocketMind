package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.memory.domain.MemoryType;

/**
 * 用户记忆上下文路径服务。
 */
public interface MemoryContextService {

    ContextUri userMemoryRoot(long userId);

    ContextUri userMemoryByType(long userId, MemoryType memoryType);
}
