package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordRepository.MemoryTypeStat;
import com.doublez.pocketmindserver.memory.domain.MemoryType;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.support.ToolCallbacks;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.stereotype.Component;

import java.util.List;
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
 */
@Slf4j
public class MemoryToolSet {

    private final long userId;
    private final MemoryRecordRepository memoryRecordRepository;

    public MemoryToolSet(long userId, MemoryRecordRepository memoryRecordRepository) {
        this.userId = userId;
        this.memoryRecordRepository = memoryRecordRepository;
    }

    @Tool(description = "浏览用户记忆分类概览。返回8类记忆的数量和摘要。对话开始时或需要了解用户背景时调用。")
    public String browseMemoryCategories() {
        List<MemoryTypeStat> stats = memoryRecordRepository.countByUserGroupByType(userId);
        if (stats.isEmpty()) {
            return "当前用户暂无长期记忆记录。";
        }
        StringBuilder sb = new StringBuilder("## 用户记忆概览\n\n");
        for (MemoryTypeStat stat : stats) {
            sb.append("- **").append(stat.memoryType().name()).append("**: ")
                    .append(stat.count()).append(" 条\n");
        }

        // 附带最近活跃的 top5 记忆标题
        List<MemoryRecordEntity> topMemories = memoryRecordRepository.findActiveByUserId(userId, 5);
        if (!topMemories.isEmpty()) {
            sb.append("\n### 最近活跃记忆\n");
            for (MemoryRecordEntity m : topMemories) {
                sb.append("- [").append(m.getMemoryType().name()).append("] ")
                        .append(m.getTitle());
                if (m.getAbstractText() != null) {
                    sb.append(" — ").append(m.getAbstractText());
                }
                sb.append("\n");
            }
        }
        return sb.toString();
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

        StringBuilder sb = new StringBuilder("## 搜索结果：" + query + "\n\n");
        for (MemoryRecordEntity m : results) {
            // 递增热度
            memoryRecordRepository.incrementActiveCount(m.getUuid());

            sb.append("### [").append(m.getMemoryType().name()).append("] ").append(m.getTitle()).append("\n");
            sb.append("- **摘要**: ").append(m.getAbstractText() != null ? m.getAbstractText() : "无").append("\n");
            sb.append("- **ID**: ").append(m.getUuid()).append("\n\n");
        }
        return sb.toString();
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
        memoryRecordRepository.incrementActiveCount(m.getUuid());

        StringBuilder sb = new StringBuilder();
        sb.append("## ").append(m.getTitle()).append("\n\n");
        sb.append("- **类型**: ").append(m.getMemoryType().name()).append("\n");
        sb.append("- **摘要**: ").append(m.getAbstractText() != null ? m.getAbstractText() : "无").append("\n");
        sb.append("- **置信度**: ").append(m.getConfidenceScore()).append("\n");
        sb.append("- **引用次数**: ").append(m.getActiveCount()).append("\n\n");

        if (m.getContent() != null && !m.getContent().isBlank()) {
            sb.append("### 详细内容\n").append(m.getContent()).append("\n\n");
        }

        if (!m.getEvidenceRefs().isEmpty()) {
            sb.append("### 来源证据\n");
            for (var ev : m.getEvidenceRefs()) {
                sb.append("- ").append(ev.sourceUri());
                if (ev.snippetRange() != null) {
                    sb.append(" (").append(ev.snippetRange()).append(")");
                }
                sb.append("\n");
            }
        }

        return sb.toString();
    }

    /**
     * 将本实例的 3 个 @Tool 方法导出为 ToolCallback 数组，供请求级注入。
     */
    public ToolCallback[] toToolCallbacks() {
        return ToolCallbacks.from(this);
    }

    /**
     * 记忆工具集工厂 — 每次请求创建 MemoryToolSet 实例（持有 userId 上下文）。
     */
    @Component
    public static class MemoryToolSetFactory {

        private final MemoryRecordRepository memoryRecordRepository;

        public MemoryToolSetFactory(MemoryRecordRepository memoryRecordRepository) {
            this.memoryRecordRepository = memoryRecordRepository;
        }

        /**
         * 为指定用户创建记忆工具集。
         */
        public MemoryToolSet createForUser(long userId) {
            return new MemoryToolSet(userId, memoryRecordRepository);
        }
    }
}
