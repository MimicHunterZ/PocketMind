package com.doublez.pocketmindserver.ai.application.memory;

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
 * <p>Phase 4 实现：关键词匹配 + 热度排序。Phase 5 升级为 pgvector 语义检索。
 */
@Slf4j
@Service
public class MemoryQueryServiceImpl implements MemoryQueryService {

    private static final int MAX_MEMORY_RESULTS = 8;

    private final MemoryContextService memoryContextService;
    private final MemoryRecordRepository memoryRecordRepository;

    public MemoryQueryServiceImpl(MemoryContextService memoryContextService,
                                  MemoryRecordRepository memoryRecordRepository) {
        this.memoryContextService = memoryContextService;
        this.memoryRecordRepository = memoryRecordRepository;
    }

    @Override
    public String buildMemoryContext(long userId, ChatSessionEntity session, String userPrompt) {
        log.debug("[memory] 查询用户记忆: userId={}, sessionUuid={}, memoryRoot={}",
                userId,
                session.getUuid(),
                memoryContextService.userMemoryRoot(userId));

        // 使用用户提问作为关键词检索记忆
        List<MemoryRecordEntity> memories = memoryRecordRepository
                .searchByKeyword(userId, userPrompt, null, MAX_MEMORY_RESULTS);

        if (memories.isEmpty()) {
            log.debug("[memory] 未找到相关记忆: userId={}", userId);
            return "";
        }

        // 递增热度并组装文本
        StringBuilder sb = new StringBuilder();
        for (MemoryRecordEntity m : memories) {
            memoryRecordRepository.incrementActiveCount(m.getUuid());

            sb.append("### [").append(m.getMemoryType().name()).append("] ").append(m.getTitle()).append("\n");
            if (m.getAbstractText() != null) {
                sb.append(m.getAbstractText()).append("\n");
            }
            if (m.getContent() != null) {
                // 截取前 500 字符避免 token 溢出
                String content = m.getContent().length() > 500
                        ? m.getContent().substring(0, 500) + "..."
                        : m.getContent();
                sb.append(content).append("\n");
            }
            sb.append("\n");
        }

        log.info("[memory] 检索到 {} 条相关记忆: userId={}", memories.size(), userId);
        return sb.toString().trim();
    }
}
