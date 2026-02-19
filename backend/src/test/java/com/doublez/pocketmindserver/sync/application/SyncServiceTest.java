package com.doublez.pocketmindserver.sync.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.sync.api.dto.SyncChangeItem;
import com.doublez.pocketmindserver.sync.api.dto.SyncPullResponse;
import com.doublez.pocketmindserver.sync.infra.persistence.SyncChangeLogMapper;
import com.doublez.pocketmindserver.sync.infra.persistence.SyncChangeLogModel;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * SyncService 单元测试
 * 验证 LWW 冲突解决逻辑
 */
class SyncServiceTest {

    private NoteRepository noteRepository;
    private SyncChangeLogMapper syncChangeLogMapper;
    private SyncService syncService;

    @BeforeEach
    void setUp() {
        noteRepository = mock(NoteRepository.class);
        syncChangeLogMapper = mock(SyncChangeLogMapper.class);
        ObjectMapper objectMapper = new ObjectMapper();

        syncService = new SyncService(
                noteRepository,
                syncChangeLogMapper,
                objectMapper
        );
    }

    // Push — 新建场景
    @Test
    void push_newNote_shouldSaveAndAppendLog() {
        UUID uuid = UUID.randomUUID();
        long userId = 1L;
        long clientTs = System.currentTimeMillis();

        when(noteRepository.findByUuidAndUserId(uuid, userId)).thenReturn(Optional.empty());

        SyncChangeItem item = buildNoteUpsert(uuid, clientTs, "新标题", "新内容");
        syncService.push(userId, List.of(item));

        verify(noteRepository).save(any(NoteEntity.class));
        verify(noteRepository, never()).update(any());
        ArgumentCaptor<SyncChangeLogModel> logCaptor = ArgumentCaptor.forClass(SyncChangeLogModel.class);
        verify(syncChangeLogMapper).insert(logCaptor.capture());
        assertEquals("note", logCaptor.getValue().getEntityType());
    }

    // Push — LWW 客户端胜出
    @Test
    void push_existingNoteWithNewerClientTs_shouldUpdate() {
        UUID uuid = UUID.randomUUID();
        long userId = 1L;
        long serverTs = 1000L;
        long clientTs = 2000L; // 客户端更新

        NoteEntity existing = NoteEntity.create(uuid, userId);
        existing.overrideUpdatedAtForSync(serverTs);

        when(noteRepository.findByUuidAndUserId(uuid, userId)).thenReturn(Optional.of(existing));

        SyncChangeItem item = buildNoteUpsert(uuid, clientTs, "客户端标题", "内容");
        syncService.push(userId, List.of(item));

        verify(noteRepository).update(any(NoteEntity.class));
        verify(noteRepository, never()).save(any());
    }


    // Push — LWW 服务端胜出
    @Test
    void push_existingNoteWithOlderClientTs_shouldSkip() {
        UUID uuid = UUID.randomUUID();
        long userId = 1L;
        long serverTs = 3000L;
        long clientTs = 2000L; // 客户端更旧

        NoteEntity existing = NoteEntity.create(uuid, userId);
        existing.overrideUpdatedAtForSync(serverTs);

        when(noteRepository.findByUuidAndUserId(uuid, userId)).thenReturn(Optional.of(existing));

        SyncChangeItem item = buildNoteUpsert(uuid, clientTs, "过期标题", "内容");
        syncService.push(userId, List.of(item));

        verify(noteRepository, never()).update(any());
        verify(noteRepository, never()).save(any());
        verifyNoInteractions(syncChangeLogMapper);
    }

    // Push — 删除场景
    @Test
    void push_deleteOperation_shouldSoftDelete() {
        UUID uuid = UUID.randomUUID();
        long userId = 1L;
        long serverTs = 1000L;
        long clientTs = 2000L;

        NoteEntity existing = NoteEntity.create(uuid, userId);
        existing.overrideUpdatedAtForSync(serverTs);
        when(noteRepository.findByUuidAndUserId(uuid, userId)).thenReturn(Optional.of(existing));

        SyncChangeItem item = new SyncChangeItem();
        item.setEntityType("note");
        item.setUuid(uuid);
        item.setOp("delete");
        item.setUpdatedAt(clientTs);

        syncService.push(userId, List.of(item));

        ArgumentCaptor<NoteEntity> captor = ArgumentCaptor.forClass(NoteEntity.class);
        verify(noteRepository).update(captor.capture());
        assertTrue(captor.getValue().isDeleted());
    }

    // Pull — 基本场景
    @Test
    void pull_shouldReturnItemsAndCorrectCursor() {
        long userId = 1L;
        long cursor = 0L;

        SyncChangeLogModel log1 = buildLog(1L, userId, UUID.randomUUID(), "note", "delete", 1000L);
        SyncChangeLogModel log2 = buildLog(2L, userId, UUID.randomUUID(), "note", "delete", 2000L);

        when(syncChangeLogMapper.findSince(userId, cursor, 201)).thenReturn(List.of(log1, log2));

        SyncPullResponse response = syncService.pull(userId, cursor, 200);

        assertFalse(response.hasMore());
        assertEquals(2000L, response.cursor());
        assertEquals(2, response.changes().size());
    }

    @Test
    void pull_withMoreData_shouldSetHasMoreTrue() {
        long userId = 1L;
        // 构造 limit+1 条，触发 hasMore=true
        List<SyncChangeLogModel> logs = java.util.stream.LongStream.rangeClosed(1, 4)
                .mapToObj(i -> buildLog(i, userId, UUID.randomUUID(), "note", "delete", i * 1000L))
                .toList();

        when(syncChangeLogMapper.findSince(userId, 0L, 4)).thenReturn(logs);

        SyncPullResponse response = syncService.pull(userId, 0L, 3);

        assertTrue(response.hasMore());
        assertEquals(3, response.changes().size());
    }

    @Test
    void pull_withNoData_shouldReturnSameCursor() {
        long userId = 1L;
        long cursor = 5000L;

        when(syncChangeLogMapper.findSince(userId, cursor, 201)).thenReturn(List.of());

        SyncPullResponse response = syncService.pull(userId, cursor, 200);

        assertFalse(response.hasMore());
        assertEquals(cursor, response.cursor());
        assertTrue(response.changes().isEmpty());
    }


    // 辅助方法
    private SyncChangeItem buildNoteUpsert(UUID uuid, long updatedAt, String title, String content) {
        SyncChangeItem item = new SyncChangeItem();
        item.setEntityType("note");
        item.setUuid(uuid);
        item.setOp("upsert");
        item.setUpdatedAt(updatedAt);
        item.setPayload("title", title);
        item.setPayload("content", content);
        return item;
    }

    private SyncChangeLogModel buildLog(long id, long userId, UUID entityUuid,
                                         String entityType, String op, long updatedAt) {
        SyncChangeLogModel m = new SyncChangeLogModel();
        m.setId(id);
        m.setUserId(userId);
        m.setEntityUuid(entityUuid);
        m.setEntityType(entityType);
        m.setOp(op);
        m.setUpdatedAt(updatedAt);
        return m;
    }
}
