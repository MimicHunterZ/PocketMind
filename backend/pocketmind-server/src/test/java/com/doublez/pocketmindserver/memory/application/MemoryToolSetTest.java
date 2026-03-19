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

class MemoryToolSetTest {

    private InMemoryMemoryRecordRepository repository;
    private MemoryToolSet toolSet;

    @BeforeEach
    void setUp() {
        repository = new InMemoryMemoryRecordRepository();
        Resource browseTpl = new ClassPathResource("prompts/memory/browse_categories.md");
        Resource searchTpl = new ClassPathResource("prompts/memory/search_results.md");
        Resource detailTpl = new ClassPathResource("prompts/memory/memory_detail.md");
        toolSet = new MemoryToolSet(1L, repository, browseTpl, searchTpl, detailTpl);
    }

    @Test
    void browseMemoryCategories_empty() {
        String result = toolSet.browseMemoryCategories();
        assertThat(result).isNotBlank();
    }

    @Test
    void browseMemoryCategories_withData() {
        seedMemory(MemoryType.PROFILE, "engineer", "profile_engineer");
        seedMemory(MemoryType.PREFERENCES, "dark mode", "pref_dark");
        String result = toolSet.browseMemoryCategories();
        assertThat(result).contains("PROFILE");
        assertThat(result).contains("PREFERENCES");
    }

    @Test
    void searchMemories_found() {
        seedMemory(MemoryType.PROFILE, "engineer", "profile_age");
        seedMemory(MemoryType.EVENTS, "japan", "event_japan");
        String result = toolSet.searchMemories("engineer", null);
        assertThat(result).doesNotContain("event_japan");
    }

    @Test
    void searchMemories_notFound() {
        seedMemory(MemoryType.PROFILE, "engineer", "profile_engineer");
        String result = toolSet.searchMemories("basketball", null);
        assertThat(result).isNotBlank();
    }

    @Test
    void searchMemories_withTypeFilter() {
        seedMemory(MemoryType.PROFILE, "engineer", "profile_engineer");
        seedMemory(MemoryType.EVENTS, "engineer conference", "event_conference");
        String result = toolSet.searchMemories("engineer", "EVENTS");
        assertThat(result).doesNotContain("profile_engineer");
    }

    @Test
    void searchMemories_incrementsActiveCount() {
        seedMemory(MemoryType.PROFILE, "engineer", "profile_engineer");
        MemoryRecordEntity record = repository.records.get(0);
        toolSet.searchMemories("engineer", null);
        assertThat(record.getActiveCount()).isEqualTo(1);
    }

    @Test
    void searchMemories_invalidType_ignoresFilter() {
        seedMemory(MemoryType.PROFILE, "engineer", "profile_engineer");
        String result = toolSet.searchMemories("engineer", "INVALID_TYPE");
        assertThat(result).isNotBlank();
    }

    @Test
    void getMemoryDetail_found() {
        seedMemory(MemoryType.PROFILE, "engineer", "profile_engineer");
        String uuid = repository.records.get(0).getUuid().toString();
        String result = toolSet.getMemoryDetail(uuid);
        assertThat(result).contains("engineer");
    }

    @Test
    void getMemoryDetail_notFound() {
        String result = toolSet.getMemoryDetail("00000000-0000-0000-0000-000000000000");
        assertThat(result).isNotBlank();
    }

    @Test
    void getMemoryDetail_invalidUuid() {
        String result = toolSet.getMemoryDetail("not-a-uuid");
        assertThat(result).isNotBlank();
    }

    @Test
    void getMemoryDetail_incrementsActiveCount() {
        seedMemory(MemoryType.PROFILE, "engineer", "profile_engineer");
        MemoryRecordEntity record = repository.records.get(0);
        toolSet.getMemoryDetail(record.getUuid().toString());
        assertThat(record.getActiveCount()).isEqualTo(1);
    }

    private void seedMemory(MemoryType type, String title, String mergeKey) {
        ContextUri rootUri = ContextUri.userMemoriesRoot(1L).child(type.name().toLowerCase());
        MemoryRecordEntity e = MemoryRecordEntity.createFromExtraction(
                1L, type, rootUri, title, title + " summary", title + " detail",
                "pm://sessions/test", List.of(MemoryEvidence.of("pm://sessions/test", title)),
                mergeKey
        );
        repository.save(e);
    }
}