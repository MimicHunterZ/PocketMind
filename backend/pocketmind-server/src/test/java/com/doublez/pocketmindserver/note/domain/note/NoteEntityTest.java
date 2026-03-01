package com.doublez.pocketmindserver.note.domain.note;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * NoteEntity 领域行为单元测试
 */
class NoteEntityTest {

    private static final UUID ID = UUID.randomUUID();
    private static final long USER_ID = 1L;

    @Test
    void create_shouldInitializeDefaults() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);

        assertEquals(ID, note.getUuid());
        assertEquals(USER_ID, note.getUserId());
        assertNull(note.getTitle());
        assertNull(note.getContent());
        assertFalse(note.isDeleted());
        // 无 URL 时默认状态为 NONE
        assertEquals(NoteResourceStatus.NONE, note.getResourceStatus());
        assertNull(note.getSummary());
        assertTrue(note.getUpdatedAt() > 0);
    }

    @Test
    void aiProcessingLifecycle_shouldUpdateStatusAndFields() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);

        note.clearSummary();
        assertNull(note.getSummary());

        note.updateSummary("总结");
        assertEquals("总结", note.getSummary());
    }

    @Test
    void updateContent_shouldChangeFields() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);
        long before = note.getUpdatedAt();

        try { Thread.sleep(1); } catch (InterruptedException ignored) {}
        note.updateContent("新标题", "新内容");

        assertEquals("新标题", note.getTitle());
        assertEquals("新内容", note.getContent());
        assertTrue(note.getUpdatedAt() >= before);
    }

    @Test
    void attachSourceUrl_shouldSetPendingStatus() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);
        assertEquals(NoteResourceStatus.NONE, note.getResourceStatus());

        note.attachSourceUrl("https://example.com");

        assertEquals("https://example.com", note.getSourceUrl());
        assertEquals(NoteResourceStatus.PENDING, note.getResourceStatus());
    }

    @Test
    void attachSourceUrl_withBlank_shouldNotChangeToPending() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);
        note.attachSourceUrl("  ");

        assertEquals(NoteResourceStatus.NONE, note.getResourceStatus());
    }

    @Test
    void startFetching_shouldSetFetchingStatus() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);
        note.attachSourceUrl("https://example.com");
        note.startFetching();

        assertEquals(NoteResourceStatus.FETCHING, note.getResourceStatus());
    }

    @Test
    void completeFetch_shouldSetDoneAndFillPreview() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);
        note.completeFetch("预览标题", "摘要", "全文");

        assertEquals("预览标题", note.getPreviewTitle());
        assertEquals("摘要", note.getPreviewDescription());
        assertEquals("全文", note.getPreviewContent());
        assertEquals(NoteResourceStatus.DONE, note.getResourceStatus());
    }

    @Test
    void failFetch_shouldSetFailedStatus() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);
        note.attachSourceUrl("https://example.com");
        note.startFetching();
        note.failFetch();

        assertEquals(NoteResourceStatus.FAILED, note.getResourceStatus());
    }

    @Test
    void resetForRetry_shouldRevertFailedToPending() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);
        note.attachSourceUrl("https://example.com");
        note.failFetch();
        note.resetForRetry();

        assertEquals(NoteResourceStatus.PENDING, note.getResourceStatus());
    }

    @Test
    void resetForRetry_nonFailedState_shouldNotChange() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);
        note.completeFetch("t", "d", "c");
        note.resetForRetry(); // DONE → should NOT change

        assertEquals(NoteResourceStatus.DONE, note.getResourceStatus());
    }

    @Test
    void softDelete_shouldMarkDeleted() {
        NoteEntity note = NoteEntity.create(ID, USER_ID);
        assertFalse(note.isDeleted());

        note.softDelete();

        assertTrue(note.isDeleted());
        assertTrue(note.getUpdatedAt() > 0);
    }
}
