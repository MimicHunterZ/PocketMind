package com.doublez.pocketmindserver.chat.domain.message;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ChatMessageEntity 领域行为单元测试
 */
class ChatMessageEntityTest {

    private static final UUID MSG_UUID     = UUID.randomUUID();
    private static final UUID SESSION_UUID = UUID.randomUUID();
    private static final long USER_ID      = 1L;

    @Test
    void create_shouldInitializeAllFields() {
        List<UUID> attachments = List.of(UUID.randomUUID());
        ChatMessageEntity msg = ChatMessageEntity.create(
                MSG_UUID, USER_ID, SESSION_UUID, ChatRole.USER, "你好", attachments);

        assertEquals(MSG_UUID, msg.getUuid());
        assertEquals(USER_ID, msg.getUserId());
        assertEquals(SESSION_UUID, msg.getSessionUuid());
        assertEquals(ChatRole.USER, msg.getRole());
        assertEquals("你好", msg.getContent());
        assertEquals(1, msg.getAttachmentUuids().size());
        assertFalse(msg.isDeleted());
        assertTrue(msg.getUpdatedAt() > 0);
    }

    @Test
    void create_withNullAttachments_shouldUseEmptyList() {
        ChatMessageEntity msg = ChatMessageEntity.create(
                MSG_UUID, USER_ID, SESSION_UUID, ChatRole.ASSISTANT, "回复", null);

        assertNotNull(msg.getAttachmentUuids());
        assertTrue(msg.getAttachmentUuids().isEmpty());
    }

    @Test
    void create_withNullUuid_shouldThrow() {
        assertThrows(NullPointerException.class,
                () -> ChatMessageEntity.create(null, USER_ID, SESSION_UUID, ChatRole.USER, "内容", null));
    }

    @Test
    void create_withNullSessionUuid_shouldThrow() {
        assertThrows(NullPointerException.class,
                () -> ChatMessageEntity.create(MSG_UUID, USER_ID, null, ChatRole.USER, "内容", null));
    }

    @Test
    void create_withNullRole_shouldThrow() {
        assertThrows(NullPointerException.class,
                () -> ChatMessageEntity.create(MSG_UUID, USER_ID, SESSION_UUID, null, "内容", null));
    }

    @Test
    void create_withNullContent_shouldThrow() {
        assertThrows(NullPointerException.class,
                () -> ChatMessageEntity.create(MSG_UUID, USER_ID, SESSION_UUID, ChatRole.USER, null, null));
    }

    @Test
    void softDelete_shouldMarkAsDeleted() {
        ChatMessageEntity msg = ChatMessageEntity.create(
                MSG_UUID, USER_ID, SESSION_UUID, ChatRole.SYSTEM, "系统", null);
        assertFalse(msg.isDeleted());

        msg.softDelete();

        assertTrue(msg.isDeleted());
    }
}
