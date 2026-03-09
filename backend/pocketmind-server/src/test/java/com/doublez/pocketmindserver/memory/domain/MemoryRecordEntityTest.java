package com.doublez.pocketmindserver.memory.domain;

import com.doublez.pocketmindserver.context.domain.ContextStatus;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.context.domain.SpaceType;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * MemoryRecordEntity 领域实体测试。
 */
class MemoryRecordEntityTest {

    @Test
    void shouldCreateFromExtraction() {
        ContextUri rootUri = ContextUri.userMemoriesRoot(1L).child("profile");
        List<MemoryEvidence> evidence = List.of(
                MemoryEvidence.of("pm://sessions/abc", "用户提到自己是年龄30的工程师")
        );

        MemoryRecordEntity entity = MemoryRecordEntity.createFromExtraction(
                1L,
                MemoryType.PROFILE,
                rootUri,
                "用户是30岁的工程师",
                "用户年龄30岁，职业为软件工程师",
                "用户说：我是一个30岁的软件工程师，平时喜欢写代码。",
                "pm://sessions/abc",
                evidence,
                "user_1_profile_age"
        );

        assertThat(entity.getUuid()).isNotNull();
        assertThat(entity.getUserId()).isEqualTo(1L);
        assertThat(entity.getSpaceType()).isEqualTo(SpaceType.USER);
        assertThat(entity.getMemoryType()).isEqualTo(MemoryType.PROFILE);
        assertThat(entity.getRootUri().value()).isEqualTo("pm://users/1/memories/profile");
        assertThat(entity.getTitle()).isEqualTo("用户是30岁的工程师");
        assertThat(entity.getMergeKey()).isEqualTo("user_1_profile_age");
        assertThat(entity.getConfidenceScore()).isEqualByComparingTo(BigDecimal.ONE);
        assertThat(entity.getActiveCount()).isZero();
        assertThat(entity.getStatus()).isEqualTo(ContextStatus.ACTIVE);
        assertThat(entity.isDeleted()).isFalse();
        assertThat(entity.getEvidenceRefs()).hasSize(1);
    }

    @Test
    void shouldIncrementActiveCount() {
        MemoryRecordEntity entity = createSample();
        assertThat(entity.getActiveCount()).isZero();

        entity.incrementActiveCount();
        assertThat(entity.getActiveCount()).isEqualTo(1);

        entity.incrementActiveCount();
        assertThat(entity.getActiveCount()).isEqualTo(2);
    }

    @Test
    void shouldUpdateContent() {
        MemoryRecordEntity entity = createSample();
        long originalUpdatedAt = entity.getUpdatedAt();

        entity.updateContent("新标题", "新摘要", "新内容");

        assertThat(entity.getTitle()).isEqualTo("新标题");
        assertThat(entity.getAbstractText()).isEqualTo("新摘要");
        assertThat(entity.getContent()).isEqualTo("新内容");
        assertThat(entity.getUpdatedAt()).isGreaterThanOrEqualTo(originalUpdatedAt);
    }

    @Test
    void shouldAddEvidence() {
        MemoryRecordEntity entity = createSample();
        assertThat(entity.getEvidenceRefs()).hasSize(1);

        entity.addEvidence(MemoryEvidence.of("pm://sessions/def", "补充证据"));

        assertThat(entity.getEvidenceRefs()).hasSize(2);
        assertThat(entity.getEvidenceRefs().get(1).sourceUri()).isEqualTo("pm://sessions/def");
    }

    @Test
    void shouldArchive() {
        MemoryRecordEntity entity = createSample();
        entity.archive();

        assertThat(entity.getStatus()).isEqualTo(ContextStatus.ARCHIVED);
    }

    @Test
    void shouldSoftDelete() {
        MemoryRecordEntity entity = createSample();
        entity.softDelete();

        assertThat(entity.isDeleted()).isTrue();
    }

    private MemoryRecordEntity createSample() {
        return MemoryRecordEntity.createFromExtraction(
                1L,
                MemoryType.PREFERENCES,
                ContextUri.userMemoriesRoot(1L).child("preferences"),
                "偏好深色模式",
                "用户偏好深色模式的 IDE",
                "用户在对话中提到偏好深色模式。",
                "pm://sessions/abc",
                List.of(MemoryEvidence.of("pm://sessions/abc", "偏好深色模式")),
                "user_1_pref_dark_mode"
        );
    }
}
