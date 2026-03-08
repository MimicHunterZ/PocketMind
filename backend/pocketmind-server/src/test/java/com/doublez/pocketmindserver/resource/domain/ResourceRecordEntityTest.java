package com.doublez.pocketmindserver.resource.domain;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ResourceRecordEntity 领域行为单元测试。
 */
class ResourceRecordEntityTest {

    @Test
    void createWebClip_shouldInitializeExpectedFields() {
        UUID uuid = UUID.randomUUID();
        UUID noteUuid = UUID.randomUUID();
        ContextUri rootUri = ContextUri.userResourcesRoot(1L).child("notes").child(noteUuid.toString()).child("source").child("web-clip");

        ResourceRecordEntity entity = ResourceRecordEntity.createWebClip(
                uuid,
                1L,
                noteUuid,
                rootUri,
                "https://example.com/post/1",
                "帖子标题",
                "帖子正文"
        );

        assertEquals(uuid, entity.getUuid());
        assertEquals(ResourceSourceType.WEB_CLIP, entity.getSourceType());
        assertEquals(noteUuid, entity.getNoteUuid());
        assertEquals("https://example.com/post/1", entity.getSourceUrl());
        assertEquals("帖子正文", entity.getContent());
        assertFalse(entity.isDeleted());
    }

    @Test
    void createChatTranscript_shouldBindSession() {
        UUID sessionUuid = UUID.randomUUID();
        ContextUri rootUri = ContextUri.userResourcesRoot(7L).child("chats").child(sessionUuid.toString()).child("transcript");

        ResourceRecordEntity entity = ResourceRecordEntity.createChatTranscript(
                UUID.randomUUID(),
                7L,
                sessionUuid,
                rootUri,
                "会话归档",
                "聊天正文"
        );

        assertEquals(ResourceSourceType.CHAT_TRANSCRIPT, entity.getSourceType());
        assertEquals(sessionUuid, entity.getSessionUuid());
    }

    @Test
    void updateContent_shouldRefreshBody() {
        UUID noteUuid = UUID.randomUUID();
        ContextUri rootUri = ContextUri.userResourcesRoot(1L).child("notes").child(noteUuid.toString()).child("source").child("note-text");
        ResourceRecordEntity entity = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(),
                1L,
                noteUuid,
                rootUri,
                "旧标题",
                "旧正文"
        );

        entity.updateContent("新标题", "新正文");

        assertEquals("新标题", entity.getTitle());
        assertEquals("新正文", entity.getContent());
    }

    @Test
    void softDelete_shouldMarkDeleted() {
        UUID assetUuid = UUID.randomUUID();
        ContextUri rootUri = ContextUri.userResourcesRoot(2L).child("assets").child(assetUuid.toString()).child("source").child("text");
        ResourceRecordEntity entity = ResourceRecordEntity.createAssetText(
                UUID.randomUUID(),
                2L,
                assetUuid,
                rootUri,
                "OCR",
                "识别文本"
        );

        entity.softDelete();

        assertTrue(entity.isDeleted());
    }
}
