package com.doublez.pocketmindserver.chat.infra.persistence.common;

import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.infra.persistence.message.ChatMessageModel;
import com.doublez.pocketmindserver.chat.infra.persistence.session.ChatSessionModel;
import org.mapstruct.factory.Mappers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ChatStructMapper（MapStruct 生成）双向转换单元测试
 */
class ChatStructMapperTest {

    private ChatStructMapper mapper;

    @BeforeEach
    void setUp() {
        mapper = Mappers.getMapper(ChatStructMapper.class);
    }

    // ----------------------------------------------------------------
    // ChatSession 双向映射
    // ----------------------------------------------------------------

    @Test
    void sessionRoundTrip_shouldPreserveAllFields() {
        UUID uuid     = UUID.randomUUID();
        UUID noteUuid = UUID.randomUUID();
        long ts       = System.currentTimeMillis();

        ChatSessionEntity original = new ChatSessionEntity(
            uuid,
            7L,
            noteUuid,
            "标题",
            "快照内容",
            ts,
            false
        );

        ChatSessionModel model    = mapper.toSessionModel(original);
        ChatSessionEntity restored = mapper.toSessionDomain(model);

        assertEquals(original.getUuid(), restored.getUuid());
        assertEquals(original.getUserId(), restored.getUserId());
        assertEquals(original.getScopeNoteUuid(), restored.getScopeNoteUuid());
        assertEquals(original.getTitle(), restored.getTitle());
        assertEquals(original.getMemorySnapshot(), restored.getMemorySnapshot());
        assertEquals(original.getUpdatedAt(), restored.getUpdatedAt());
        assertEquals(original.isDeleted(), restored.isDeleted());
    }

    @Test
    void toSessionModel_deletedFlagMapped() {
        ChatSessionEntity session = ChatSessionEntity.create(UUID.randomUUID(), 1L, null, "s");
        session.softDelete();

        ChatSessionModel model = mapper.toSessionModel(session);

        assertTrue(Boolean.TRUE.equals(model.getIsDeleted()));
    }

    @Test
    void toSessionDomain_nullUpdatedAt_defaultsToZero() {
        ChatSessionModel model = new ChatSessionModel();
        model.setUuid(UUID.randomUUID());
        model.setUserId(1L);
        model.setUpdatedAt(null);

        ChatSessionEntity entity = mapper.toSessionDomain(model);

        assertEquals(0L, entity.getUpdatedAt());
        assertFalse(entity.isDeleted());
    }

    // ----------------------------------------------------------------
    // ChatMessage 双向映射
    // ----------------------------------------------------------------

    @Test
    void messageRoundTrip_shouldPreserveAllFields() {
        UUID uuid        = UUID.randomUUID();
        UUID sessionUuid = UUID.randomUUID();
        UUID attachUuid  = UUID.randomUUID();
        long ts          = System.currentTimeMillis();

        ChatMessageEntity original = ChatMessageEntity.create(
                uuid, 5L, sessionUuid, ChatRole.USER, "消息内容", List.of(attachUuid));
        original = new ChatMessageEntity(
                uuid,
                5L,
                sessionUuid,
                null,           // parentUuid
                "TEXT",         // messageType
                ChatRole.USER,
                "消息内容",
                List.of(attachUuid),
                ts,
                false
        );

        ChatMessageModel model     = mapper.toMessageModel(original);
        ChatMessageEntity restored = mapper.toMessageDomain(model);

        assertEquals(original.getUuid(), restored.getUuid());
        assertEquals(original.getUserId(), restored.getUserId());
        assertEquals(original.getSessionUuid(), restored.getSessionUuid());
        assertEquals(original.getRole(), restored.getRole());
        assertEquals(original.getContent(), restored.getContent());
        assertEquals(original.getAttachmentUuids(), restored.getAttachmentUuids());
        assertEquals(original.getUpdatedAt(), restored.getUpdatedAt());
        assertEquals(original.isDeleted(), restored.isDeleted());
    }

    @Test
    void toMessageModel_deletedFlagMapped() {
        ChatMessageEntity msg = ChatMessageEntity.create(
                UUID.randomUUID(), 1L, UUID.randomUUID(), ChatRole.ASSISTANT, "回复", null);
        msg.softDelete();

        ChatMessageModel model = mapper.toMessageModel(msg);

        assertTrue(Boolean.TRUE.equals(model.getIsDeleted()));
    }

    @Test
    void toMessageDomain_nullUpdatedAt_defaultsToZero() {
        ChatMessageModel model = new ChatMessageModel();
        model.setUuid(UUID.randomUUID());
        model.setUserId(1L);
        model.setSessionUuid(UUID.randomUUID());
        model.setRole(ChatRole.USER);
        model.setContent("test");
        model.setUpdatedAt(null);

        ChatMessageEntity entity = mapper.toMessageDomain(model);

        assertEquals(0L, entity.getUpdatedAt());
        assertFalse(entity.isDeleted());
    }
}
