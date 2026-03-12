package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.memory.domain.MemoryEvidence;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * MemoryToolSet 工具方法测试。
 */
class MemoryToolSetTest {

    private InMemoryMemoryRecordRepository repository;
    private MemoryToolSet toolSet;

    @BeforeEach
    void setUp() {
        repository = new InMemoryMemoryRecordRepository();
        Resource browseTpl = new ClassPathResource("prompts/memory/browse_categories.md");
        Resource searchTpl = new ClassPathResource("prompts/memory/search_results.md");
        Resource detailTpl = new ClassPathResource("prompts/memory/memory_detail.md");
        Resource statItemTpl = new ClassPathResource("prompts/memory/stat_item.md");
        Resource topMemoryItemTpl = new ClassPathResource("prompts/memory/top_memory_item.md");
        Resource searchResultItemTpl = new ClassPathResource("prompts/memory/search_result_item.md");
        Resource evidenceItemTpl = new ClassPathResource("prompts/memory/evidence_item.md");
        toolSet = new MemoryToolSet(1L, repository, browseTpl, searchTpl, detailTpl,
                statItemTpl, topMemoryItemTpl, searchResultItemTpl, evidenceItemTpl);
    }

    // ─── browseMemoryCategories ──────────────────────────────

    @Test
    void browseMemoryCategories_empty() {
        String result = toolSet.browseMemoryCategories();
        assertThat(result).contains("暂无长期记忆记录");
    }

    @Test
    void browseMemoryCategories_withData() {
        seedMemory(MemoryType.PROFILE, "用户是工程师", "profile_engineer");
        seedMemory(MemoryType.PREFERENCES, "偏好深色模式", "pref_dark");

        String result = toolSet.browseMemoryCategories();
        assertThat(result).contains("用户记忆概览");
        assertThat(result).contains("PROFILE");
        assertThat(result).contains("PREFERENCES");
        assertThat(result).contains("用户是工程师");
        assertThat(result).contains("偏好深色模式");
    }

    // ─── searchMemories ──────────────────────────────────────

    @Test
    void searchMemories_found() {
        seedMemory(MemoryType.PROFILE, "用户是30岁工程师", "profile_age");
        seedMemory(MemoryType.EVENTS, "去过日本旅游", "event_japan");

        String result = toolSet.searchMemories("工程师", null);
        assertThat(result).contains("搜索结果");
        assertThat(result).contains("用户是30岁工程师");
        assertThat(result).doesNotContain("去过日本旅游");
    }

    @Test
    void searchMemories_notFound() {
        seedMemory(MemoryType.PROFILE, "用户是工程师", "profile_engineer");

        String result = toolSet.searchMemories("篮球", null);
        assertThat(result).contains("未找到");
    }

    @Test
    void searchMemories_withTypeFilter() {
        seedMemory(MemoryType.PROFILE, "用户是工程师", "profile_engineer");
        seedMemory(MemoryType.EVENTS, "工程师大会", "event_conference");

        // 搜索 "工程师" 但只要 EVENTS 类型
        String result = toolSet.searchMemories("工程师", "EVENTS");
        assertThat(result).contains("工程师大会");
        assertThat(result).doesNotContain("用户是工程师");
    }

    @Test
    void searchMemories_incrementsActiveCount() {
        seedMemory(MemoryType.PROFILE, "用户是工程师", "profile_engineer");
        MemoryRecordEntity record = repository.records.get(0);
        assertThat(record.getActiveCount()).isZero();

        toolSet.searchMemories("工程师", null);
        assertThat(record.getActiveCount()).isEqualTo(1);
    }

    @Test
    void searchMemories_invalidType_ignoresFilter() {
        seedMemory(MemoryType.PROFILE, "用户是工程师", "profile_engineer");

        String result = toolSet.searchMemories("工程师", "INVALID_TYPE");
        // 无效类型应被忽略，搜索全部
        assertThat(result).contains("用户是工程师");
    }

    // ─── getMemoryDetail ─────────────────────────────────────

    @Test
    void getMemoryDetail_found() {
        seedMemory(MemoryType.PROFILE, "用户是工程师", "profile_engineer");
        String uuid = repository.records.get(0).getUuid().toString();

        String result = toolSet.getMemoryDetail(uuid);
        assertThat(result).contains("用户是工程师");
        assertThat(result).contains("PROFILE");
        assertThat(result).contains("详细内容");
        assertThat(result).contains("来源证据");
    }

    @Test
    void getMemoryDetail_notFound() {
        String result = toolSet.getMemoryDetail("00000000-0000-0000-0000-000000000000");
        assertThat(result).contains("未找到");
    }

    @Test
    void getMemoryDetail_invalidUuid() {
        String result = toolSet.getMemoryDetail("not-a-uuid");
        assertThat(result).contains("无效的记忆 ID 格式");
    }

    @Test
    void getMemoryDetail_incrementsActiveCount() {
        seedMemory(MemoryType.PROFILE, "用户是工程师", "profile_engineer");
        MemoryRecordEntity record = repository.records.get(0);
        assertThat(record.getActiveCount()).isZero();

        toolSet.getMemoryDetail(record.getUuid().toString());
        assertThat(record.getActiveCount()).isEqualTo(1);
    }

    // ─── helper ──────────────────────────────────────────────

    private void seedMemory(MemoryType type, String title, String mergeKey) {
        ContextUri rootUri = ContextUri.userMemoriesRoot(1L).child(type.name().toLowerCase());
        MemoryRecordEntity e = MemoryRecordEntity.createFromExtraction(
                1L,
                type,
                rootUri,
                title,
                title + "的摘要",
                title + "的详细内容文本",
                "pm://sessions/test-session",
                List.of(MemoryEvidence.of("pm://sessions/test-session", title)),
                mergeKey
        );
        repository.save(e);
    }
}
