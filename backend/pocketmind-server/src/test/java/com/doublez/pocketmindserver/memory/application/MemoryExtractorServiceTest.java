package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.context.application.SessionCommitResult;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryType;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * MemoryExtractorServiceImpl 单元测试。
 * 使用 Mock AiFailoverRouter 避免实际 LLM 调用。
 */
class MemoryExtractorServiceTest {

    private InMemoryMemoryRecordRepository memoryRepo;
    private StubResourceRecordRepository resourceRepo;
    private AiFailoverRouter aiFailoverRouter;
    private MemoryExtractorServiceImpl service;

    private static final long USER_ID = 1L;
    private static final UUID SESSION_UUID = UUID.randomUUID();

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        memoryRepo = new InMemoryMemoryRecordRepository();
        resourceRepo = new StubResourceRecordRepository();
        MemoryContextService memoryContextService = new MemoryContextServiceImpl();
        aiFailoverRouter = mock(AiFailoverRouter.class);

        service = new MemoryExtractorServiceImpl(
                memoryRepo,
                resourceRepo,
                memoryContextService,
                aiFailoverRouter
        );

        // 注入 @Value 资源
        Resource systemTemplate = new ByteArrayResource(
                "你是记忆抽取专家。输出格式：<format>".getBytes());
        Resource userTemplate = new ByteArrayResource(
                "会话标题：<sessionTitle>\n摘要：<summary>\n已有记忆：<existingMemories>\n<format>".getBytes());
        ReflectionTestUtils.setField(service, "extractionSystemTemplate", systemTemplate);
        ReflectionTestUtils.setField(service, "extractionUserTemplate", userTemplate);
    }

    @Test
    @SuppressWarnings("unchecked")
    void shouldExtractNewMemories() {
        // 准备：存入摘要资源
        UUID summaryUuid = UUID.randomUUID();
        resourceRepo.seedResource(summaryUuid, USER_ID, "用户提到他是一名30岁的Java工程师，偏好深色模式。");

        SessionCommitResult commitResult = new SessionCommitResult(
                SESSION_UUID, UUID.randomUUID(), summaryUuid, 10, "自我介绍对话"
        );

        // Mock LLM 返回
        MemoryExtractionResult llmResult = new MemoryExtractionResult(List.of(
                new MemoryExtractionResult.MemoryCandidate(
                        "PROFILE", "30岁的Java工程师", "用户年龄30岁，职业为Java工程师",
                        "用户在对话中自述为30岁的Java工程师", "user_1_profile_engineer"
                ),
                new MemoryExtractionResult.MemoryCandidate(
                        "PREFERENCES", "偏好深色模式", "用户习惯使用深色模式的开发工具",
                        "用户提到偏好深色模式", "user_1_pref_dark"
                )
        ));
        when(aiFailoverRouter.executeChat(eq("memoryExtraction"), any(Function.class)))
                .thenReturn(llmResult);

        int count = service.extractFromCommit(USER_ID, SESSION_UUID, commitResult);

        assertThat(count).isEqualTo(2);
        assertThat(memoryRepo.records).hasSize(2);
        assertThat(memoryRepo.records.get(0).getMemoryType()).isEqualTo(MemoryType.PROFILE);
        assertThat(memoryRepo.records.get(1).getMemoryType()).isEqualTo(MemoryType.PREFERENCES);
    }

    @Test
    @SuppressWarnings("unchecked")
    void shouldMergeExistingMemoryByMergeKey() {
        // 已有记忆
        MemoryRecordEntity existing = MemoryRecordEntity.createFromExtraction(
                USER_ID, MemoryType.PROFILE,
                ContextUri.userMemoriesRoot(USER_ID).child("profile"),
                "旧标题", "旧摘要", "旧内容",
                "pm://sessions/old",
                List.of(),
                "user_1_profile_engineer"
        );
        memoryRepo.save(existing);

        UUID summaryUuid = UUID.randomUUID();
        resourceRepo.seedResource(summaryUuid, USER_ID, "用户又一次提到了自己是高级工程师。");

        SessionCommitResult commitResult = new SessionCommitResult(
                SESSION_UUID, UUID.randomUUID(), summaryUuid, 5, "工程师身份确认"
        );

        // LLM 返回与已有记忆同 mergeKey 的候选
        MemoryExtractionResult llmResult = new MemoryExtractionResult(List.of(
                new MemoryExtractionResult.MemoryCandidate(
                        "PROFILE", "高级Java工程师", "用户确认自己为高级Java工程师",
                        "用户多次提到自己是高级Java工程师", "user_1_profile_engineer"
                )
        ));
        when(aiFailoverRouter.executeChat(eq("memoryExtraction"), any(Function.class)))
                .thenReturn(llmResult);

        int count = service.extractFromCommit(USER_ID, SESSION_UUID, commitResult);

        assertThat(count).isEqualTo(1);
        // 未新增记录，而是更新已有
        assertThat(memoryRepo.records).hasSize(1);
        MemoryRecordEntity merged = memoryRepo.records.get(0);
        assertThat(merged.getTitle()).isEqualTo("高级Java工程师");
        assertThat(merged.getContent()).isEqualTo("用户多次提到自己是高级Java工程师");
        assertThat(merged.getEvidenceRefs()).hasSize(1); // 原始 0 + 新增 1
    }

    @Test
    void shouldReturnZeroWhenSummaryIsEmpty() {
        // 摘要资源不存在
        SessionCommitResult commitResult = new SessionCommitResult(
                SESSION_UUID, UUID.randomUUID(), null, 0, "无摘要"
        );

        int count = service.extractFromCommit(USER_ID, SESSION_UUID, commitResult);
        assertThat(count).isZero();
    }

    @Test
    @SuppressWarnings("unchecked")
    void shouldReturnZeroWhenLlmReturnsEmpty() {
        UUID summaryUuid = UUID.randomUUID();
        resourceRepo.seedResource(summaryUuid, USER_ID, "一些对话内容");

        SessionCommitResult commitResult = new SessionCommitResult(
                SESSION_UUID, UUID.randomUUID(), summaryUuid, 5, "对话"
        );

        MemoryExtractionResult emptyResult = new MemoryExtractionResult(List.of());
        when(aiFailoverRouter.executeChat(eq("memoryExtraction"), any(Function.class)))
                .thenReturn(emptyResult);

        int count = service.extractFromCommit(USER_ID, SESSION_UUID, commitResult);
        assertThat(count).isZero();
        assertThat(memoryRepo.records).isEmpty();
    }

    @Test
    @SuppressWarnings("unchecked")
    void shouldReturnZeroWhenLlmThrowsException() {
        UUID summaryUuid = UUID.randomUUID();
        resourceRepo.seedResource(summaryUuid, USER_ID, "一些对话内容");

        SessionCommitResult commitResult = new SessionCommitResult(
                SESSION_UUID, UUID.randomUUID(), summaryUuid, 5, "对话"
        );

        when(aiFailoverRouter.executeChat(eq("memoryExtraction"), any(Function.class)))
                .thenThrow(new RuntimeException("LLM 调用失败"));

        int count = service.extractFromCommit(USER_ID, SESSION_UUID, commitResult);
        assertThat(count).isZero();
        assertThat(memoryRepo.records).isEmpty();
    }

    @Test
    @SuppressWarnings("unchecked")
    void shouldSkipUnknownMemoryType() {
        UUID summaryUuid = UUID.randomUUID();
        resourceRepo.seedResource(summaryUuid, USER_ID, "一些对话内容");

        SessionCommitResult commitResult = new SessionCommitResult(
                SESSION_UUID, UUID.randomUUID(), summaryUuid, 5, "对话"
        );

        // LLM 返回一个有效和一个无效类型
        MemoryExtractionResult llmResult = new MemoryExtractionResult(List.of(
                new MemoryExtractionResult.MemoryCandidate(
                        "UNKNOWN_TYPE", "某个记忆", "摘要", "内容", "merge_unknown"
                ),
                new MemoryExtractionResult.MemoryCandidate(
                        "EVENTS", "去过日本", "去年夏天去了日本", "详细行程内容", "user_1_event_japan"
                )
        ));
        when(aiFailoverRouter.executeChat(eq("memoryExtraction"), any(Function.class)))
                .thenReturn(llmResult);

        int count = service.extractFromCommit(USER_ID, SESSION_UUID, commitResult);

        // 仅保存了有效类型那条
        assertThat(count).isEqualTo(1);
        assertThat(memoryRepo.records).hasSize(1);
        assertThat(memoryRepo.records.get(0).getMemoryType()).isEqualTo(MemoryType.EVENTS);
    }

    // ─── Stub ResourceRecordRepository ───────────────────────

    private static class StubResourceRecordRepository implements ResourceRecordRepository {
        private final java.util.ArrayList<ResourceRecordEntity> storage = new java.util.ArrayList<>();

        void seedResource(UUID uuid, long userId, String content) {
            ResourceRecordEntity entity = ResourceRecordEntity.createChatStageSummary(
                    uuid, userId, UUID.randomUUID(),
                    ContextUri.userMemoriesRoot(userId),
                    "摘要", "一句话摘要", "结构化摘要", content
            );
            storage.add(entity);
        }

        @Override public void save(ResourceRecordEntity r) { storage.add(r); }
        @Override public void update(ResourceRecordEntity r) {}
        @Override public Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
            return storage.stream()
                    .filter(r -> r.getUuid().equals(uuid) && r.getUserId() == userId)
                    .findFirst();
        }
        @Override public List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid) { return List.of(); }
        @Override public List<ResourceRecordEntity> findBySessionUuid(long userId, UUID uuid) { return List.of(); }
        @Override public List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid) { return List.of(); }
    }
}
