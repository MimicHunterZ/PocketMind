package com.doublez.pocketmindserver.ai.application.memory;

import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.memory.application.MemoryContextService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 长期记忆查询默认实现。
 *
 * 当前阶段先明确 AGFS 路径边界，不直接以数据库作为长期记忆主存。
 * 真正的检索实现会在后续 Memory 抽取与索引阶段接入。
 */
@Slf4j
@Service
public class MemoryQueryServiceImpl implements MemoryQueryService {

    private final MemoryContextService memoryContextService;

    public MemoryQueryServiceImpl(MemoryContextService memoryContextService) {
        this.memoryContextService = memoryContextService;
    }

    @Override
    public String buildMemoryContext(long userId, ChatSessionEntity session, String userPrompt) {
        log.debug("[memory] AGFS 长期记忆查询尚未接入，userId={}, sessionUuid={}, memoryRoot={}",
                userId,
                session.getUuid(),
                memoryContextService.userMemoryRoot(userId));
        return "";
    }
}
