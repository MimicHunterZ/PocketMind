package com.doublez.pocketmindserver.attachment.domain.vision;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * AttachmentVisionEntity 领域行为单元测试
 */
class AttachmentVisionEntityTest {

    @Test
    void create_shouldBeInPendingStatus() {
        AttachmentVisionEntity e = AttachmentVisionEntity.create(
                UUID.randomUUID(), 1L, UUID.randomUUID(), "gpt-4o");

        assertEquals(VisionStatus.PENDING, e.getStatus());
        assertNull(e.getVisionText());
    }

    @Test
    void markDone_shouldSetTextAndStatus() {
        AttachmentVisionEntity e = AttachmentVisionEntity.create(
                UUID.randomUUID(), 1L, UUID.randomUUID(), "gpt-4o");

        e.markDone("识别到一只猫", "请描述图片内容");

        assertEquals(VisionStatus.DONE, e.getStatus());
        assertEquals("识别到一只猫", e.getVisionText());
        assertEquals("请描述图片内容", e.getPromptUsed());
    }

    @Test
    void markDone_withNullText_shouldThrow() {
        AttachmentVisionEntity e = AttachmentVisionEntity.create(
                UUID.randomUUID(), 1L, UUID.randomUUID(), "gpt-4o");

        assertThrows(NullPointerException.class, () -> e.markDone(null, null));
    }

    @Test
    void markFailed_shouldSetStatusToFailed() {
        AttachmentVisionEntity e = AttachmentVisionEntity.create(
                UUID.randomUUID(), 1L, UUID.randomUUID(), "gpt-4o");

        e.markFailed();

        assertEquals(VisionStatus.FAILED, e.getStatus());
        assertNull(e.getVisionText());
    }
}
