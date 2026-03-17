package com.doublez.pocketmindserver.context.application;

import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextLayer;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.resource.application.ChatTranscriptResourceSyncService;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogSyncService;
import com.doublez.pocketmindserver.resource.application.ResourceContextService;
import com.doublez.pocketmindserver.resource.application.ResourceContextServiceImpl;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;
import com.doublez.pocketmind.common.web.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.core.io.ClassPathResource;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

/**
 * SessionCommitService 单元测试。
 *
 * <p>使用内存仓库 + Mock AiFailoverRouter 验证提交编排逻辑。
 */
@ExtendWith(MockitoExtension.class)
class SessionCommitServiceTest {

    private static final long USER_ID = 42L;

    private final InMemoryChatMessageRepository messageRepo = new InMemoryChatMessageRepository();
    private final InMemoryChatSessionRepository sessionRepo = new InMemoryChatSessionRepository();
    private final InMemoryResourceRecordRepository resourceRepo = new InMemoryResourceRecordRepository();
    private final InMemoryContextCatalogRepository catalogRepo = new InMemoryContextCatalogRepository();
    private final ResourceContextService contextService = new ResourceContextServiceImpl();
    private final NoOpCatalogSyncService catalogSyncService = new NoOpCatalogSyncService();
    private final RecordingTranscriptSyncService transcriptSyncService = new RecordingTranscriptSyncService();

    @Mock
    private AiFailoverRouter aiFailoverRouter;

    private SessionCommitServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new SessionCommitServiceImpl(
                sessionRepo,
                messageRepo,
                transcriptSyncService,
                resourceRepo,
                contextService,
                catalogSyncService,
                catalogRepo,
                aiFailoverRouter,
                (userId, sessionUuid, commitResult) -> 0  // no-op memory extractor for unit test
        );
        // 注入 @Value 模板资源（单元测试无 Spring 上下文）
        ReflectionTestUtils.setField(service, "summarySystemTemplate",
                new ClassPathResource("prompts/compression/structured_summary_system.md"));
        ReflectionTestUtils.setField(service, "summaryUserTemplate",
                new ClassPathResource("prompts/compression/structured_summary_user.md"));
        ReflectionTestUtils.setField(service, "transcriptMessageTemplate",
                new ClassPathResource("prompts/chat/transcript_message.md"));
    }

    @Test
    void shouldCommitSessionSuccessfully() {
        UUID sessionUuid = UUID.randomUUID();
        sessionRepo.session = ChatSessionEntity.create(sessionUuid, USER_ID, null, "讨论 Spring AI");

        messageRepo.storage.add(ChatMessageEntity.create(
                UUID.randomUUID(), USER_ID, sessionUuid, ChatRole.USER, "Spring AI 怎么用？", List.of()));
        messageRepo.storage.add(ChatMessageEntity.create(
                UUID.randomUUID(), USER_ID, sessionUuid, ChatRole.ASSISTANT, "Spring AI 提供了统一的 LLM 抽象层。", List.of()));

        // 模拟 transcript 同步后会在 resourceRepo 中生成一条 CHAT_TRANSCRIPT
        transcriptSyncService.onSync = (userId, sUuid) -> {
            ResourceRecordEntity transcript = ResourceRecordEntity.createChatTranscript(
                    UUID.randomUUID(), userId, sUuid,
                    contextService.chatTranscriptResource(userId, sUuid),
                    "讨论 Spring AI", "用户：Spring AI 怎么用？\n\n助手：Spring AI 提供了统一的 LLM 抽象层。"
            );
            resourceRepo.save(transcript);
        };

        // Mock LLM 返回
        when(aiFailoverRouter.executeChat(eq("sessionCommitSummary"), any()))
                .thenAnswer(invocation -> {
                    // 直接返回模拟的 StructuredSummaryResult
                    return new SessionCommitServiceImpl.StructuredSummaryResult(
                            "讨论 Spring AI 框架的基本用法",
                            "## 讨论主题\nSpring AI 框架入门\n## 关键结论\n- 提供统一 LLM 抽象层"
                    );
                });

        SessionCommitResult result = service.commit(USER_ID, sessionUuid);

        assertThat(result.sessionUuid()).isEqualTo(sessionUuid);
        assertThat(result.messageCount()).isEqualTo(2);
        assertThat(result.abstractText()).contains("Spring AI");
        assertThat(result.transcriptResourceUuid()).isNotNull();
        assertThat(result.summaryResourceUuid()).isNotNull();

        // 验证 CHAT_STAGE_SUMMARY resource 被创建
        List<ResourceRecordEntity> summaries = resourceRepo.storage.stream()
                .filter(r -> r.getSourceType() == ResourceSourceType.CHAT_STAGE_SUMMARY)
                .toList();
        assertThat(summaries).hasSize(1);
        assertThat(summaries.getFirst().getAbstractText()).contains("Spring AI");
        assertThat(summaries.getFirst().getSummaryText()).contains("讨论主题");

        // 验证 transcript sync 被调用
        assertThat(transcriptSyncService.syncCalled).isTrue();
    }

    @Test
    void shouldThrowWhenSessionNotFound() {
        UUID sessionUuid = UUID.randomUUID();

        assertThatThrownBy(() -> service.commit(USER_ID, sessionUuid))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).getDetail().toString())
                        .contains("会话不存在"));
    }

    @Test
    void shouldThrowWhenNoValidMessages() {
        UUID sessionUuid = UUID.randomUUID();
        sessionRepo.session = ChatSessionEntity.create(sessionUuid, USER_ID, null, "空会话");

        assertThatThrownBy(() -> service.commit(USER_ID, sessionUuid))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).getDetail().toString())
                        .contains("无有效消息"));
    }

    @Test
    void shouldUpdateExistingSummaryOnRecommit() {
        UUID sessionUuid = UUID.randomUUID();
        sessionRepo.session = ChatSessionEntity.create(sessionUuid, USER_ID, null, "重复提交测试");

        messageRepo.storage.add(ChatMessageEntity.create(
                UUID.randomUUID(), USER_ID, sessionUuid, ChatRole.USER, "第一次提问", List.of()));
        messageRepo.storage.add(ChatMessageEntity.create(
                UUID.randomUUID(), USER_ID, sessionUuid, ChatRole.ASSISTANT, "第一次回答", List.of()));

        // 预先放一条 transcript
        transcriptSyncService.onSync = (userId, sUuid) -> {
            if (resourceRepo.findBySessionUuid(userId, sUuid).stream()
                    .noneMatch(r -> r.getSourceType() == ResourceSourceType.CHAT_TRANSCRIPT)) {
                resourceRepo.save(ResourceRecordEntity.createChatTranscript(
                        UUID.randomUUID(), userId, sUuid,
                        contextService.chatTranscriptResource(userId, sUuid),
                        "重复提交测试", "用户：第一次提问\n\n助手：第一次回答"
                ));
            }
        };

        when(aiFailoverRouter.executeChat(eq("sessionCommitSummary"), any()))
                .thenReturn(new SessionCommitServiceImpl.StructuredSummaryResult(
                        "第一次摘要", "## 讨论主题\n首次讨论"))
                .thenReturn(new SessionCommitServiceImpl.StructuredSummaryResult(
                        "更新后的摘要", "## 讨论主题\n更新后讨论"));

        // 第一次提交
        service.commit(USER_ID, sessionUuid);

        // 第二次提交 — 应更新而非新建
        SessionCommitResult result = service.commit(USER_ID, sessionUuid);

        long summaryCount = resourceRepo.storage.stream()
                .filter(r -> r.getSourceType() == ResourceSourceType.CHAT_STAGE_SUMMARY)
                .filter(r -> !r.isDeleted())
                .count();
        assertThat(summaryCount).isEqualTo(1);
        assertThat(result.abstractText()).isEqualTo("更新后的摘要");
    }

    // ─── 内存仓库实现 ──────────────────────────────────────────────

    private static final class InMemoryChatMessageRepository implements ChatMessageRepository {
        final List<ChatMessageEntity> storage = new ArrayList<>();

        @Override public void save(ChatMessageEntity message) { storage.add(message); }
        @Override public void appendContent(UUID messageUuid, long userId, String delta, long updatedAt) {}
        @Override public Optional<ChatMessageEntity> findByUuidAndUserId(UUID uuid, long userId) {
            return storage.stream().filter(m -> m.getUuid().equals(uuid) && m.getUserId() == userId).findFirst();
        }
        @Override public List<ChatMessageEntity> findBySessionUuid(long userId, UUID sessionUuid, PageQuery pageQuery) {
            return storage.stream()
                    .filter(m -> m.getUserId() == userId && m.getSessionUuid().equals(sessionUuid))
                    .sorted(Comparator.comparingLong(ChatMessageEntity::getUpdatedAt))
                    .toList();
        }
        @Override public List<ChatMessageEntity> findChangedSince(long userId, SyncCursorQuery query) { return List.of(); }
        @Override public List<ChatMessageEntity> findChain(UUID leafUuid, long userId) { return List.of(); }
        @Override public List<ChatMessageEntity> findChildrenByParentUuid(UUID parentUuid, long userId) { return List.of(); }
        @Override public void updateRating(UUID uuid, long userId, int rating) {}
        @Override public void updateContent(UUID uuid, long userId, String content) {}
        @Override public void updateBranchAlias(UUID uuid, long userId, String alias) {}
        @Override public void softDeleteByUuids(List<UUID> uuids, long userId) {}
        @Override public void softDeleteAssistantChildren(UUID parentUuid, long userId) {}
    }

    private static final class InMemoryChatSessionRepository implements ChatSessionRepository {
        ChatSessionEntity session;

        @Override public void save(ChatSessionEntity session) { this.session = session; }
        @Override public void update(ChatSessionEntity session) { this.session = session; }
        @Override public Optional<ChatSessionEntity> findByUuidAndUserId(UUID uuid, long userId) {
            if (session != null && session.getUuid().equals(uuid) && session.getUserId() == userId) {
                return Optional.of(session);
            }
            return Optional.empty();
        }
        @Override public List<ChatSessionEntity> findByUserId(long userId, PageQuery pageQuery) { return List.of(); }
        @Override public List<ChatSessionEntity> findByNoteUuid(long userId, UUID noteUuid) { return List.of(); }
        @Override public List<ChatSessionEntity> findChangedSince(long userId, SyncCursorQuery query) { return List.of(); }
        @Override public void updateTitleByUuidAndUserId(UUID uuid, long userId, String title) {}
        @Override public void deleteByUuidAndUserId(UUID uuid, long userId) {}
    }

    private static final class InMemoryResourceRecordRepository implements ResourceRecordRepository {
        final List<ResourceRecordEntity> storage = new ArrayList<>();

        @Override public void save(ResourceRecordEntity resourceRecord) { storage.add(resourceRecord); }
        @Override public void update(ResourceRecordEntity resourceRecord) {
            for (int i = 0; i < storage.size(); i++) {
                if (storage.get(i).getUuid().equals(resourceRecord.getUuid())) {
                    storage.set(i, resourceRecord);
                    return;
                }
            }
            storage.add(resourceRecord);
        }

        @Override
        public Optional<ResourceRecordEntity> findByRootUriAndUserId(String rootUri, long userId) {
            return storage.stream()
                .filter(r -> java.util.Objects.equals(r.getRootUri(), rootUri) && r.getUserId() == userId)
                .findFirst();
        }
        @Override public Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
            return storage.stream().filter(r -> r.getUuid().equals(uuid) && r.getUserId() == userId).findFirst();
        }
        @Override public List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid) { return List.of(); }
        @Override public List<ResourceRecordEntity> findBySessionUuid(long userId, UUID sessionUuid) {
            return storage.stream()
                    .filter(r -> r.getUserId() == userId && sessionUuid.equals(r.getSessionUuid()) && !r.isDeleted())
                    .toList();
        }
        @Override public List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid) { return List.of(); }
    }

    private static final class InMemoryContextCatalogRepository implements ContextCatalogRepository {
        final List<String> incrementedUris = new ArrayList<>();

        @Override public List<ContextNode> findChildrenByParentUri(String parentUri, long userId) { return List.of(); }
        @Override public List<ContextNode> findDescendantsByUriPrefix(String uriPrefix, long userId) { return List.of(); }
        @Override public List<ContextNode> searchByKeyword(String keyword, Long userId, ContextType contextType, int limit) { return List.of(); }
        @Override public Optional<ContextNode> findByUri(String uri) { return Optional.empty(); }
        @Override public List<ContextNode> findByUris(List<String> uris) { return List.of(); }
        @Override public void upsert(ContextNode node, Long userId) {}
        @Override public void incrementActiveCount(String uri) { incrementedUris.add(uri); }
        @Override public void incrementActiveCountBatch(List<String> uris) { incrementedUris.addAll(uris); }
        @Override public void deleteByUri(String uri) {}
        @Override public List<ScoredCatalogEntry> searchByVector(float[] queryVector, long userId, ContextType contextType, int limit) { return List.of(); }
        @Override public List<ScoredCatalogEntry> searchChildrenByVector(float[] queryVector, String parentUri, long userId, int limit) { return List.of(); }
        @Override public void updateEmbedding(String uri, float[] embedding) {}
    }

    private static final class NoOpCatalogSyncService implements ResourceCatalogSyncService {
        @Override public void syncToCatalog(ResourceRecordEntity resource) {}
        @Override public void removeFromCatalog(ResourceRecordEntity resource) {}
    }

    /**
     * 可编程的 transcript 同步服务 — 支持在测试中注入回调模拟同步行为。
     */
    private static final class RecordingTranscriptSyncService implements ChatTranscriptResourceSyncService {
        boolean syncCalled = false;
        SyncCallback onSync;

        @Override
        public void syncSessionTranscript(long userId, UUID sessionUuid) {
            syncCalled = true;
            if (onSync != null) {
                onSync.execute(userId, sessionUuid);
            }
        }

        @Override
        public void softDeleteBySession(long userId, UUID sessionUuid) {}

        @FunctionalInterface
        interface SyncCallback {
            void execute(long userId, UUID sessionUuid);
        }
    }
}
