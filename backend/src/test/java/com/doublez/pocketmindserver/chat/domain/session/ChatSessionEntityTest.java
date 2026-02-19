package com.doublez.pocketmindserver.chat.domain.session;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ChatSessionEntity 领域行为单元测试
 */
class ChatSessionEntityTest {

    private static final UUID SESSION_UUID = UUID.randomUUID();
    private static final UUID NOTE_UUID    = UUID.randomUUID();
    private static final long USER_ID      = 42L;

    @Test
    void create_shouldInitializeAllFields() {
        ChatSessionEntity session = ChatSessionEntity.create(SESSION_UUID, USER_ID, NOTE_UUID, "测试会话");

        assertEquals(SESSION_UUID, session.getUuid());
        assertEquals(USER_ID, session.getUserId());
        assertEquals(NOTE_UUID, session.getScopeNoteUuid());
        assertEquals("测试会话", session.getTitle());
        assertFalse(session.isDeleted());
        assertTrue(session.getUpdatedAt() > 0);
    }

    @Test
    void create_withNullUuid_shouldThrow() {
        assertThrows(NullPointerException.class,
                () -> ChatSessionEntity.create(null, USER_ID, NOTE_UUID, "title"));
    }

    @Test
    void create_withNullScopeNote_shouldBeAllowed() {
        ChatSessionEntity session = ChatSessionEntity.create(SESSION_UUID, USER_ID, null, "全局会话");
        assertNull(session.getScopeNoteUuid());
    }

    @Test
    void updateTitle_shouldChangeTitle() {
        ChatSessionEntity session = ChatSessionEntity.create(SESSION_UUID, USER_ID, NOTE_UUID, "旧标题");
        long before = session.getUpdatedAt();

        try { Thread.sleep(1); } catch (InterruptedException ignored) {}
        session.updateTitle("新标题");

        assertEquals("新标题", session.getTitle());
        assertTrue(session.getUpdatedAt() >= before);
    }

    @Test
    void softDelete_shouldMarkAsDeleted() {
        ChatSessionEntity session = ChatSessionEntity.create(SESSION_UUID, USER_ID, NOTE_UUID, "会话");
        assertFalse(session.isDeleted());

        session.softDelete();

        assertTrue(session.isDeleted());
    }
}
