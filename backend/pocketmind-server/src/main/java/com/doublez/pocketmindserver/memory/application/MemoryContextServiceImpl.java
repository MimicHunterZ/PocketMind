package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.memory.domain.MemoryType;
import org.springframework.stereotype.Service;

/**
 * 默认用户记忆上下文路径服务实现。
 */
@Service
public class MemoryContextServiceImpl implements MemoryContextService {

    @Override
    public ContextUri userMemoryRoot(long userId) {
        return ContextUri.userMemoriesRoot(userId);
    }

    @Override
    public ContextUri userMemoryByType(long userId, MemoryType memoryType) {
        return ContextUri.userMemoriesRoot(userId)
                .child(memoryType.name().toLowerCase());
    }
}
