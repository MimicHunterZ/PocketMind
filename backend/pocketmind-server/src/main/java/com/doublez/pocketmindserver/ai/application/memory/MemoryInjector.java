package com.doublez.pocketmindserver.ai.application.memory;

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

    @Value("classpath:prompts/chat/context/memory_all_section.md")
    private Resource memoryAllSectionTemplate;

    @Value("classpath:prompts/chat/context/memory_all_item.md")
    private Resource memoryAllItemTemplate;

    public MemoryInjector(MemoryRecordRepository memoryRecordRepository) {
        this.memoryRecordRepository = memoryRecordRepository;
    }

    /**
     * 构建可注入系统提示词的全量记忆段落。
     */
    public String buildAllMemorySection(long userId) {
        return buildAllMemorySection(userId, DEFAULT_INJECTION_LIMIT);
    }

    /**
     * 构建可注入系统提示词的全量记忆段落。
     */
    public String buildAllMemorySection(long userId, int limit) {
        List<MemoryRecordEntity> memories = memoryRecordRepository.findActiveByUserId(userId, limit);
        if (memories.isEmpty()) {
            return "";
        }

        try {
            String items = memories.stream()
                    .map(this::renderItem)
                    .collect(Collectors.joining("\n"));

            return PromptBuilder.render(memoryAllSectionTemplate, Map.of(
                    "count", String.valueOf(memories.size()),
                    "items", items
            ));
        } catch (IOException e) {
            throw new UncheckedIOException("渲染全量记忆模板失败", e);
        }
    }

    private String renderItem(MemoryRecordEntity memory) {
        try {
            return PromptBuilder.render(memoryAllItemTemplate, Map.of(
                    "memoryType", memory.getMemoryType().name(),
                    "title", safeText(memory.getTitle()),
                    "abstractText", safeText(memory.getAbstractText())
            ));
        } catch (IOException e) {
            log.warn("[memory-injector] 渲染记忆项失败: uuid={}, error={}", memory.getUuid(), e.getMessage());
            return "";
        }
    }

    private String safeText(String text) {
        return text == null ? "" : text;
    }
}
