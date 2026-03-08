package com.doublez.pocketmindserver.sync.application;

import com.doublez.pocketmindserver.note.domain.category.CategoryEntity;
import com.doublez.pocketmindserver.note.domain.category.CategoryRepository;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.resource.application.NoteResourceSyncService;
import com.doublez.pocketmindserver.sync.api.dto.SyncMutationDto;
import com.doublez.pocketmindserver.sync.api.dto.SyncPullResponse;
import com.doublez.pocketmindserver.sync.api.dto.SyncPushRequest;
import com.doublez.pocketmindserver.sync.api.dto.SyncPushResult;
import com.doublez.pocketmindserver.sync.domain.SyncChangeLogRepository;
import com.doublez.pocketmindserver.sync.event.NoteAiPipelineEvent;
import com.doublez.pocketmindserver.sync.infra.persistence.SyncChangeLogModel;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * SyncService 单元测试。
 * <p>
 * 所有外部依赖均 Mock；TransactionTemplate 配置为直接执行 callback，
 * 使测试无需容器而保持逻辑等价性。
 * </p>
 */
@ExtendWith(MockitoExtension.class)
class SyncServiceTest {

    @Mock private NoteRepository noteRepository;
    @Mock private CategoryRepository categoryRepository;
    @Mock private SyncChangeLogRepository changeLogRepository;
    @Mock private TransactionTemplate transactionTemplate;
    @Mock private ApplicationEventPublisher eventPublisher;
    @Mock private NoteResourceSyncService noteResourceSyncService;

    private SyncServiceImpl service;

    private static final long USER_ID = 100L;
    private static final long SERVER_VERSION = 42L;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        service = new SyncServiceImpl(
                noteRepository,
                categoryRepository,
                changeLogRepository,
                transactionTemplate,
                eventPublisher,
                new ObjectMapper(),
                noteResourceSyncService
        );
        // 让 TransactionTemplate 直接执行回调，模拟事务内行为
        lenient().doAnswer(inv -> {
            TransactionCallback<?> callback = inv.getArgument(0);
            return callback.doInTransaction(null);
        }).when(transactionTemplate).execute(any());
    }

    // =========================================================================
    // Pull
    // =========================================================================

    @Nested
    @DisplayName("pull — 增量拉取")
    class PullTests {

        @Test
        @DisplayName("基础场景：变更条目少于 pageSize，hasMore=false")
        void pull_basicCase_returnsChangesAndCursor() {
            SyncChangeLogModel row = makeChangeLogRow(10L, "note", UUID.randomUUID(), "create", 1000L, "{\"uuid\":\"abc\"}");
            when(changeLogRepository.findSince(USER_ID, 0L, 201)).thenReturn(List.of(row));

            SyncPullResponse resp = service.pull(USER_ID, 0L, 200);

            assertThat(resp.hasMore()).isFalse();
            assertThat(resp.serverVersion()).isEqualTo(10L);
            assertThat(resp.changes()).hasSize(1);
            assertThat(resp.changes().get(0).serverVersion()).isEqualTo(10L);
            assertThat(resp.changes().get(0).operation()).isEqualTo("create");
        }

        @Test
        @DisplayName("hasMore=true：结果超出 pageSize，截断并翻页")
        void pull_hasMore_truncatesAndSetsFlag() {
            List<SyncChangeLogModel> rows = generateRows(3, 10L); // 生成 id=10,11,12
            when(changeLogRepository.findSince(USER_ID, 0L, 3)).thenReturn(rows); // pageSize=2, fetchLimit=3

            SyncPullResponse resp = service.pull(USER_ID, 0L, 2);

            assertThat(resp.hasMore()).isTrue();
            assertThat(resp.changes()).hasSize(2);
            assertThat(resp.serverVersion()).isEqualTo(11L); // 截断后第 2 条的 id
        }

        @Test
        @DisplayName("空结果：游标不变，changes 为空列表")
        void pull_empty_cursorUnchanged() {
            when(changeLogRepository.findSince(USER_ID, 99L, 201)).thenReturn(Collections.emptyList());

            SyncPullResponse resp = service.pull(USER_ID, 99L, 200);

            assertThat(resp.hasMore()).isFalse();
            assertThat(resp.serverVersion()).isEqualTo(99L);
            assertThat(resp.changes()).isEmpty();
        }
    }

    // =========================================================================
    // Push — Note
    // =========================================================================

    @Nested
    @DisplayName("push — 笔记 Mutation")
    class PushNoteTests {

        @Test
        @DisplayName("create：新建笔记，返回 accepted + serverVersion")
        void push_createNote_accepted() {
            UUID noteUuid = UUID.randomUUID();
            String mutationId = UUID.randomUUID().toString();

            when(changeLogRepository.findVersionByMutationId(mutationId)).thenReturn(Optional.empty());
            when(noteRepository.findByUuidAndUserId(noteUuid, USER_ID)).thenReturn(Optional.empty());
            when(noteRepository.findTagNamesByUuid(noteUuid, USER_ID)).thenReturn(Collections.emptyList());
            when(changeLogRepository.insert(anyLong(), eq("note"), eq(noteUuid),
                    eq("create"), anyLong(), eq(mutationId), anyString()))
                    .thenReturn(SERVER_VERSION);

            SyncPushRequest request = new SyncPushRequest(List.of(
                    new SyncMutationDto(mutationId, "note", noteUuid.toString(), "create",
                            System.currentTimeMillis(), Map.of("title", "测试笔记", "content", "正文"))
            ));

            List<SyncPushResult> results = service.push(USER_ID, request);

            assertThat(results).hasSize(1);
            SyncPushResult result = results.get(0);
            assertThat(result.accepted()).isTrue();
            assertThat(result.serverVersion()).isEqualTo(SERVER_VERSION);
            assertThat(result.mutationId()).isEqualTo(mutationId);
            verify(noteRepository).save(any(NoteEntity.class));
            verify(noteRepository).updateServerVersion(eq(noteUuid), eq(USER_ID), eq(SERVER_VERSION));
        }

        @Test
        @DisplayName("update：客户端 updatedAt >= 服务端 updatedAt，客户端胜出，返回 accepted")
        void push_updateNote_clientWins() {
            UUID noteUuid = UUID.randomUUID();
            String mutationId = UUID.randomUUID().toString();
            long serverUpdatedAt = 1000L;
            long clientUpdatedAt = 2000L; // 客户端更新

            NoteEntity serverNote = noteWith(noteUuid, USER_ID, serverUpdatedAt);
            when(changeLogRepository.findVersionByMutationId(mutationId)).thenReturn(Optional.empty());
            when(noteRepository.findByUuidAndUserId(noteUuid, USER_ID)).thenReturn(Optional.of(serverNote));
            when(noteRepository.findTagNamesByUuid(noteUuid, USER_ID)).thenReturn(Collections.emptyList());
            when(changeLogRepository.insert(anyLong(), anyString(), any(), anyString(), anyLong(), anyString(), anyString()))
                    .thenReturn(SERVER_VERSION);

            SyncPushRequest request = new SyncPushRequest(List.of(
                    new SyncMutationDto(mutationId, "note", noteUuid.toString(), "update",
                            clientUpdatedAt, Map.of("title", "新标题", "content", "新内容"))
            ));

            List<SyncPushResult> results = service.push(USER_ID, request);

            assertThat(results.get(0).accepted()).isTrue();
            verify(noteRepository).update(serverNote);
        }

        @Test
        @DisplayName("update：服务端 updatedAt > 客户端 updatedAt，服务端胜出，返回 conflict")
        void push_updateNote_serverWins() {
            UUID noteUuid = UUID.randomUUID();
            String mutationId = UUID.randomUUID().toString();
            long serverUpdatedAt = 3000L;
            long clientUpdatedAt = 1000L; // 客户端更旧

            NoteEntity serverNote = noteWith(noteUuid, USER_ID, serverUpdatedAt);
            when(changeLogRepository.findVersionByMutationId(mutationId)).thenReturn(Optional.empty());
            when(noteRepository.findByUuidAndUserId(noteUuid, USER_ID)).thenReturn(Optional.of(serverNote));
            when(noteRepository.findTagNamesByUuid(noteUuid, USER_ID)).thenReturn(Collections.emptyList());

            SyncPushRequest request = new SyncPushRequest(List.of(
                    new SyncMutationDto(mutationId, "note", noteUuid.toString(), "update",
                            clientUpdatedAt, Map.of("title", "旧标题"))
            ));

            List<SyncPushResult> results = service.push(USER_ID, request);

            SyncPushResult result = results.get(0);
            assertThat(result.accepted()).isFalse();
            assertThat(result.conflictEntity()).isNotNull();
            assertThat(result.conflictEntity()).containsKey("uuid");
            // 服务端胜出时不应调用 update
            verify(noteRepository, never()).update(any());
        }

        @Test
        @DisplayName("delete：软删除现有笔记，返回 accepted")
        void push_deleteNote_accepted() {
            UUID noteUuid = UUID.randomUUID();
            String mutationId = UUID.randomUUID().toString();
            NoteEntity serverNote = noteWith(noteUuid, USER_ID, 1000L);

            when(changeLogRepository.findVersionByMutationId(mutationId)).thenReturn(Optional.empty());
            when(noteRepository.findByUuidAndUserId(noteUuid, USER_ID)).thenReturn(Optional.of(serverNote));
            when(changeLogRepository.insert(anyLong(), eq("note"), eq(noteUuid),
                    eq("delete"), anyLong(), eq(mutationId), isNull()))
                    .thenReturn(SERVER_VERSION);

            SyncPushRequest request = new SyncPushRequest(List.of(
                    new SyncMutationDto(mutationId, "note", noteUuid.toString(), "delete",
                            System.currentTimeMillis(), Map.of())
            ));

            List<SyncPushResult> results = service.push(USER_ID, request);

            assertThat(results.get(0).accepted()).isTrue();
            verify(noteRepository).softDeleteByUuidAndUserId(eq(noteUuid), eq(USER_ID), anyLong());
            verify(noteRepository).updateServerVersion(eq(noteUuid), eq(USER_ID), eq(SERVER_VERSION));
        }

        @Test
        @DisplayName("幂等重放：同一 mutationId 已存在，直接返回历史 serverVersion")
        void push_idempotentReplay_returnsCachedVersion() {
            String mutationId = UUID.randomUUID().toString();
            when(changeLogRepository.findVersionByMutationId(mutationId))
                    .thenReturn(Optional.of(SERVER_VERSION));

            SyncPushRequest request = new SyncPushRequest(List.of(
                    new SyncMutationDto(mutationId, "note", UUID.randomUUID().toString(), "create",
                            System.currentTimeMillis(), Map.of("title", "任意"))
            ));

            List<SyncPushResult> results = service.push(USER_ID, request);

            assertThat(results.get(0).accepted()).isTrue();
            assertThat(results.get(0).serverVersion()).isEqualTo(SERVER_VERSION);
            // 幂等命中时绝不应修改数据库
            verify(noteRepository, never()).save(any());
            verify(noteRepository, never()).update(any());
        }

        @Test
        @DisplayName("create：含有效 URL 时，应触发 NoteAiPipelineEvent")
        void push_createNote_withUrl_triggersAiPipelineEvent() {
            UUID noteUuid = UUID.randomUUID();
            String mutationId = UUID.randomUUID().toString();

            when(changeLogRepository.findVersionByMutationId(mutationId)).thenReturn(Optional.empty());
            when(noteRepository.findByUuidAndUserId(noteUuid, USER_ID)).thenReturn(Optional.empty());
            when(noteRepository.findTagNamesByUuid(noteUuid, USER_ID)).thenReturn(Collections.emptyList());
            when(changeLogRepository.insert(anyLong(), anyString(), any(), anyString(), anyLong(), anyString(), anyString()))
                    .thenReturn(SERVER_VERSION);

            SyncPushRequest request = new SyncPushRequest(List.of(
                    new SyncMutationDto(mutationId, "note", noteUuid.toString(), "create",
                            System.currentTimeMillis(),
                            Map.of("title", "测试", "content", "正文", "url", "https://example.com"))
            ));

            service.push(USER_ID, request);

            ArgumentCaptor<NoteAiPipelineEvent> captor = ArgumentCaptor.forClass(NoteAiPipelineEvent.class);
            verify(eventPublisher).publishEvent(captor.capture());
            assertThat(captor.getValue().noteUuid()).isEqualTo(noteUuid);
            assertThat(captor.getValue().userId()).isEqualTo(USER_ID);
        }
    }

    // =========================================================================
    // Push — Category
    // =========================================================================

    @Nested
    @DisplayName("push — 分类 Mutation")
    class PushCategoryTests {

        @Test
        @DisplayName("create：新建分类，返回 accepted")
        void push_createCategory_accepted() {
            UUID catUuid = UUID.randomUUID();
            String mutationId = UUID.randomUUID().toString();

            when(changeLogRepository.findVersionByMutationId(mutationId)).thenReturn(Optional.empty());
            when(categoryRepository.findByUuidAndUserId(catUuid, USER_ID)).thenReturn(Optional.empty());
            when(changeLogRepository.insert(anyLong(), eq("category"), eq(catUuid),
                    eq("create"), anyLong(), eq(mutationId), anyString()))
                    .thenReturn(SERVER_VERSION);

            SyncPushRequest request = new SyncPushRequest(List.of(
                    new SyncMutationDto(mutationId, "category", catUuid.toString(), "create",
                            System.currentTimeMillis(), Map.of("name", "工作"))
            ));

            List<SyncPushResult> results = service.push(USER_ID, request);

            assertThat(results.get(0).accepted()).isTrue();
            assertThat(results.get(0).serverVersion()).isEqualTo(SERVER_VERSION);
            verify(categoryRepository).save(any(CategoryEntity.class));
        }
    }

    // =========================================================================
    // Push — unknown entityType
    // =========================================================================

    @Nested
    @DisplayName("push — 未知 entityType")
    class PushUnknownEntityTypeTests {

        @Test
        @DisplayName("未知 entityType 返回 rejected，不崩溃")
        void push_unknownEntityType_rejected() {
            String mutationId = UUID.randomUUID().toString();

            SyncPushRequest request = new SyncPushRequest(List.of(
                    new SyncMutationDto(mutationId, "unknown_type", UUID.randomUUID().toString(),
                            "create", System.currentTimeMillis(), Map.of())
            ));

            List<SyncPushResult> results = service.push(USER_ID, request);

            assertThat(results.get(0).accepted()).isFalse();
            assertThat(results.get(0).rejectReason()).startsWith("UNKNOWN_ENTITY_TYPE");
        }

        @Test
        @DisplayName("服务端内部异常返回 retryable 结果，避免客户端误判为永久失败")
        void push_serverError_marksRetryable() {
            String mutationId = UUID.randomUUID().toString();
            UUID noteUuid = UUID.randomUUID();

            when(changeLogRepository.findVersionByMutationId(mutationId)).thenReturn(Optional.empty());
            when(noteRepository.findByUuidAndUserId(noteUuid, USER_ID)).thenThrow(new IllegalStateException("db down"));

            SyncPushRequest request = new SyncPushRequest(List.of(
                    new SyncMutationDto(mutationId, "note", noteUuid.toString(),
                            "update", System.currentTimeMillis(), Map.of())
            ));

            List<SyncPushResult> results = service.push(USER_ID, request);

            assertThat(results).hasSize(1);
            assertThat(results.get(0).accepted()).isFalse();
            assertThat(results.get(0).retryable()).isTrue();
            assertThat(results.get(0).rejectReason()).isEqualTo("SERVER_ERROR");
        }
    }


    // =========================================================================
    // persistAiResult
    // =========================================================================

    @Nested
    @DisplayName("persistAiResult — AI 管线回写")
    class PersistAiResultTests {

        @Test
        @DisplayName("正常场景：更新 AI 字段，追加 change_log，推进 serverVersion")
        void persistAiResult_updatesAndAppendChangeLog() {
            UUID noteUuid = UUID.randomUUID();
            NoteEntity note = noteWith(noteUuid, USER_ID, 1000L);

            when(noteRepository.findByUuidAndUserId(noteUuid, USER_ID)).thenReturn(Optional.of(note));
            when(noteRepository.findTagNamesByUuid(noteUuid, USER_ID)).thenReturn(Collections.emptyList());
            when(changeLogRepository.insert(anyLong(), eq("note"), eq(noteUuid),
                    eq("update"), anyLong(), isNull(), anyString()))
                    .thenReturn(SERVER_VERSION);

            service.persistAiResult(noteUuid, USER_ID,
                    "AI 摘要内容", "DONE", "预览标题", "预览描述", "预览正文");

            verify(noteRepository).updateAiFields(
                    eq(noteUuid), eq(USER_ID),
                    eq("AI 摘要内容"), eq("DONE"),
                    eq("预览标题"), eq("预览描述"), eq("预览正文"));
            // clientMutationId 必须为 null（AI 回写不是客户端发起）
            verify(changeLogRepository).insert(
                    eq(USER_ID), eq("note"), eq(noteUuid), eq("update"),
                    anyLong(), isNull(), anyString());
            verify(noteRepository).updateServerVersion(noteUuid, USER_ID, SERVER_VERSION);
        }

        @Test
        @DisplayName("笔记不存在时：不崩溃，不写 change_log")
        void persistAiResult_noteNotFound_noChangeLog() {
            UUID noteUuid = UUID.randomUUID();
            when(noteRepository.findByUuidAndUserId(noteUuid, USER_ID)).thenReturn(Optional.empty());

            service.persistAiResult(noteUuid, USER_ID, "摘要", "DONE", null, null, null);

            verify(changeLogRepository, never()).insert(anyLong(), anyString(), any(), anyString(),
                    anyLong(), any(), any());
        }
    }

    // =========================================================================
    // 辅助工厂方法
    // =========================================================================

    /** 创建一个指定 updatedAt 的 NoteEntity（通过构造函数直接创建，绕过工厂方法限制） */
    private NoteEntity noteWith(UUID uuid, long userId, long updatedAt) {
        return new NoteEntity(uuid, userId, "标题", "内容", null, 1L,
                Collections.emptyList(), java.time.Instant.now(),
                null, null, null,
                com.doublez.pocketmindserver.note.domain.note.NoteResourceStatus.NONE,
                null, null, updatedAt, false, null);
    }

    /**
     * 生成 {@code count} 条 change_log mock 对象，id 从 {@code startId} 开始连续递增。
     */
    private List<SyncChangeLogModel> generateRows(int count, long startId) {
        return java.util.stream.LongStream.range(startId, startId + count)
                .mapToObj(id -> makeChangeLogRow(id, "note", UUID.randomUUID(), "create", 1000L, null))
                .toList();
    }

    private SyncChangeLogModel makeChangeLogRow(long id, String entityType, UUID entityUuid,
                                                 String operation, long updatedAt, String payload) {
        return new SyncChangeLogModel()
                .setId(id)
                .setUserId(USER_ID)
                .setEntityType(entityType)
                .setEntityUuid(entityUuid)
                .setOperation(operation)
                .setUpdatedAt(updatedAt)
                .setPayload(payload);
    }
}
