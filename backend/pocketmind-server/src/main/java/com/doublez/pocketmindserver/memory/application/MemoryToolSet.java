package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository.MemoryTypeStat;
import com.doublez.pocketmindserver.memory.domain.MemoryType;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.support.ToolCallbacks;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 用户长期记忆工具集 — 供 AI 在对话中主动召回记忆。
 *
 * <p>三个工具：
 * <ul>
 *   <li>{@link #browseMemoryCategories()} — 浏览记忆分类概览</li>
 *   <li>{@link #searchMemories(String, String)} — 关键词搜索记忆</li>
 *   <li>{@link #getMemoryDetail(String)} — 获取单条记忆完整详情</li>
 * </ul>
 *
 * <p>因为需要 userId 上下文，本类每次请求创建实例（非单例 Bean），
 * 通过 {@link MemoryToolSetFactory} 获取。
 * <p>所有文本渲染通过 PromptBuilder + 外部 .md 模板完成，禁止 StringBuilder 拼接。
 */
@Slf4j
public class MemoryToolSet {

    private final long userId;
    private final MemoryRecordRepository memoryRecordRepository;

    // ── 外层模板 ──
    private final Resource browseCategoriesTemplate;
    private final Resource searchResultsTemplate;
    private final Resource memoryDetailTemplate;

    // ── 条目级模板（替代内部 StringBuilder 拼接） ──
    private final Resource statItemTemplate;
    private final Resource topMemoryItemTemplate;
    private final Resource searchResultItemTemplate;
    private final Resource evidenceItemTemplate;

    public MemoryToolSet(long userId,
                         MemoryRecordRepository memoryRecordRepository,
                         Resource browseCategoriesTemplate,
                         Resource searchResultsTemplate,
                         Resource memoryDetailTemplate,
                         Resource statItemTemplate,
                         Resource topMemoryItemTemplate,
                         Resource searchResultItemTemplate,
                         Resource evidenceItemTemplate) {
        this.userId = userId;
        this.memoryRecordRepository = memoryRecordRepository;
        this.browseCategoriesTemplate = browseCategoriesTemplate;
        this.searchResultsTemplate = searchResultsTemplate;
        this.memoryDetailTemplate = memoryDetailTemplate;
        this.statItemTemplate = statItemTemplate;
        this.topMemoryItemTemplate = topMemoryItemTemplate;
        this.searchResultItemTemplate = searchResultItemTemplate;
        this.evidenceItemTemplate = evidenceItemTemplate;
    }

    @Tool(description = "浏览用户记忆分类概览。返回各类记忆的数量和摘要。对话开始时或需要了解用户背景时调用。")
    public String browseMemoryCategories() {
        List<MemoryTypeStat> stats = memoryRecordRepository.countByUserGroupByType(userId);
        if (stats.isEmpty()) {
            return "当前用户暂无长期记忆记录。";
        }

        // 渲染分类统计条目
        String statsText = stats.stream()
                .map(stat -> renderItem(statItemTemplate, Map.of(
                        "memoryType", stat.memoryType().name(),
                        "count", String.valueOf(stat.count())
                )))
                .collect(Collectors.joining());

        // 渲染最近活跃记忆条目
        List<MemoryRecordEntity> topMemories = memoryRecordRepository.findActiveByUserId(userId, 5);
        String topText = topMemories.stream()
                .map(m -> renderItem(topMemoryItemTemplate, Map.of(
                        "memoryType", m.getMemoryType().name(),
                        "title", m.getTitle() != null ? m.getTitle() : "未命名",
                        "suffix", m.getAbstractText() != null ? " — " + m.getAbstractText() : ""
                )))
                .collect(Collectors.joining());

        try {
            return PromptBuilder.render(browseCategoriesTemplate, Map.of(
                    "stats", statsText,
                    "topMemories", topText
            ));
        } catch (IOException e) {
            log.error("[memory-tool] 渲染 browse_categories 模板失败", e);
            return "记忆概览加载失败。";
        }
    }

    @Tool(description = "搜索用户相关记忆。返回匹配记忆的摘要列表。需要查找与话题相关的用户记忆时使用。")
    public String searchMemories(
            @ToolParam(description = "搜索关键词") String query,
            @ToolParam(description = "记忆类型过滤（可选）：PROFILE/PREFERENCES/ENTITIES/EVENTS，留空搜索全部", required = false) String type) {
        MemoryType memoryType = null;
        if (type != null && !type.isBlank()) {
            try {
                memoryType = MemoryType.valueOf(type.toUpperCase());
            } catch (IllegalArgumentException e) {
                log.debug("[memory-tool] 未识别的记忆类型: {}", type);
            }
        }

        List<MemoryRecordEntity> results = memoryRecordRepository.searchByKeyword(userId, query, memoryType, 10);
        if (results.isEmpty()) {
            return "未找到与「" + query + "」相关的记忆。";
        }

        // 渲染搜索结果条目
        String resultsText = results.stream()
                .map(m -> {
                    memoryRecordRepository.incrementActiveCount(m.getUuid(), m.getUserId());
                    return renderItem(searchResultItemTemplate, Map.of(
                            "memoryType", m.getMemoryType().name(),
                            "title", m.getTitle() != null ? m.getTitle() : "未命名",
                            "abstractText", m.getAbstractText() != null ? m.getAbstractText() : "无",
                            "uuid", m.getUuid().toString()
                    ));
                })
                .collect(Collectors.joining("\n"));

        try {
            return PromptBuilder.render(searchResultsTemplate, Map.of(
                    "query", query,
                    "results", resultsText
            ));
        } catch (IOException e) {
            log.error("[memory-tool] 渲染 search_results 模板失败", e);
            return "搜索结果加载失败。";
        }
    }

    @Tool(description = "获取单条记忆的完整详情（含全部内容和来源引用）。确认需要某条记忆的详细信息时调用。")
    public String getMemoryDetail(
            @ToolParam(description = "记忆 UUID") String memoryId) {
        UUID uuid;
        try {
            uuid = UUID.fromString(memoryId);
        } catch (IllegalArgumentException e) {
            return "无效的记忆 ID 格式。";
        }

        Optional<MemoryRecordEntity> opt = memoryRecordRepository.findByUuidAndUserId(uuid, userId);
        if (opt.isEmpty()) {
            return "未找到 ID 为 " + memoryId + " 的记忆。";
        }

        MemoryRecordEntity m = opt.get();
        memoryRecordRepository.incrementActiveCount(m.getUuid(), m.getUserId());

        // 渲染来源证据条目
        String evidenceText;
        if (!m.getEvidenceRefs().isEmpty()) {
            evidenceText = m.getEvidenceRefs().stream()
                    .map(ev -> renderItem(evidenceItemTemplate, Map.of(
                            "sourceUri", ev.sourceUri(),
                            "snippet", ev.snippetRange() != null ? " (" + ev.snippetRange() + ")" : ""
                    )))
                    .collect(Collectors.joining());
        } else {
            evidenceText = "无来源证据\n";
        }

        try {
            return PromptBuilder.render(memoryDetailTemplate, Map.of(
                    "title", m.getTitle() != null ? m.getTitle() : "未命名记忆",
                    "memoryType", m.getMemoryType().name(),
                    "abstractText", m.getAbstractText() != null ? m.getAbstractText() : "无",
                    "confidenceScore", m.getConfidenceScore().toString(),
                    "activeCount", String.valueOf(m.getActiveCount()),
                    "content", m.getContent() != null && !m.getContent().isBlank() ? m.getContent() : "无详细内容",
                    "evidenceList", evidenceText
            ));
        } catch (IOException e) {
            log.error("[memory-tool] 渲染 memory_detail 模板失败", e);
            return "记忆详情加载失败。";
        }
    }

    /**
     * 将本实例的 3 个 @Tool 方法导出为 ToolCallback 数组，供请求级注入。
     */
    public ToolCallback[] toToolCallbacks() {
        return ToolCallbacks.from(this);
    }

    /**
     * 使用条目级模板渲染单个数据项，IOException 转为 UncheckedIOException。
     */
    private String renderItem(Resource template, Map<String, Object> variables) {
        try {
            return PromptBuilder.render(template, variables);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    /**
     * 记忆工具集工厂 — 每次请求创建 MemoryToolSet 实例（持有 userId 上下文）。
     */
    @Component
    public static class MemoryToolSetFactory {

        private final MemoryRecordRepository memoryRecordRepository;

        // ── 外层模板 ──
        @Value("classpath:prompts/memory/browse_categories.md")
        private Resource browseCategoriesTemplate;

        @Value("classpath:prompts/memory/search_results.md")
        private Resource searchResultsTemplate;

        @Value("classpath:prompts/memory/memory_detail.md")
        private Resource memoryDetailTemplate;

        // ── 条目级模板 ──
        @Value("classpath:prompts/memory/stat_item.md")
        private Resource statItemTemplate;

        @Value("classpath:prompts/memory/top_memory_item.md")
        private Resource topMemoryItemTemplate;

        @Value("classpath:prompts/memory/search_result_item.md")
        private Resource searchResultItemTemplate;

        @Value("classpath:prompts/memory/evidence_item.md")
        private Resource evidenceItemTemplate;

        public MemoryToolSetFactory(MemoryRecordRepository memoryRecordRepository) {
            this.memoryRecordRepository = memoryRecordRepository;
        }

        /**
         * 为指定用户创建记忆工具集。
         */
        public MemoryToolSet createForUser(long userId) {
            return new MemoryToolSet(userId, memoryRecordRepository,
                    browseCategoriesTemplate, searchResultsTemplate, memoryDetailTemplate,
                    statItemTemplate, topMemoryItemTemplate, searchResultItemTemplate, evidenceItemTemplate);
        }
    }
}
