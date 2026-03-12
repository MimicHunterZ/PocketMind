package com.doublez.pocketmindserver.ai.application.memory;

import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.memory.application.MemoryContextService;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 长期记忆查询实现 — 从 memory_records 检索与当前对话相关的记忆，组装为上下文文本。
 *
 * <p>基于关键词匹配 + 热度排序检索相关记忆。
 */
@Slf4j
@Service
public class MemoryQueryServiceImpl implements MemoryQueryService {

    private static final int MAX_MEMORY_RESULTS = 8;

    private final MemoryContextService memoryContextService;
    private final MemoryRecordRepository memoryRecordRepository;

    /** 记忆上下文外层模板（包裹所有记忆条目） */
    @Value("classpath:prompts/memory/memory_context.md")
    private Resource memoryContextTemplate;

    /** 单条记忆条目渲染模板 */
    @Value("classpath:prompts/memory/memory_context_item.md")
    private Resource memoryContextItemTemplate;

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

        List<MemoryRecordEntity> memories = memoryRecordRepository
                .searchByKeyword(userId, userPrompt, null, MAX_MEMORY_RESULTS);

        if (memories.isEmpty()) {
            log.debug("[memory] 未找到相关记忆: userId={}", userId);
            return "";
        }

        // 逐条递增热度并渲染为模板文本，不截断 content
        String items = memories.stream()
                .map(m -> {
                    memoryRecordRepository.incrementActiveCount(m.getUuid());
                    try {
                        return PromptBuilder.render(memoryContextItemTemplate, Map.of(
                                "memoryType", m.getMemoryType().name(),
                                "title", m.getTitle() != null ? m.getTitle() : "未命名",
                                "abstractText", m.getAbstractText() != null ? m.getAbstractText() : "",
                                "content", m.getContent() != null ? m.getContent() : ""
                        ));
                    } catch (IOException e) {
                        throw new UncheckedIOException(e);
                    }
                })
                .collect(Collectors.joining("\n"));

        log.info("[memory] 检索到 {} 条相关记忆: userId={}", memories.size(), userId);
        try {
            return PromptBuilder.render(memoryContextTemplate, Map.of("memories", items));
        } catch (IOException e) {
            throw new UncheckedIOException("加载记忆上下文模板失败", e);
        }
    }
}
