package com.doublez.pocketmindserver.attachment.domain.attachment;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * AttachmentEntity 领域行为单元测试
 */
class AttachmentEntityTest {

    private static final UUID UUID_ATT = UUID.randomUUID();
    private static final UUID UUID_NOTE = UUID.randomUUID();
    private static final long USER_ID = 1L;

//    @Test
//    void create_shouldInitializeDefaults() {
//        AttachmentEntity e = AttachmentEntity.create(
//                UUID_ATT, USER_ID, UUID_NOTE,
//                AttachmentType.IMAGE, "image/jpeg",
//                "pocket_images/test.jpg", StorageType.LOCAL,
//                "sha256abc", 800, 600, AttachmentSource.USER);
//
//        assertEquals(UUID_ATT, e.getUuid());
//        assertEquals(USER_ID, e.getUserId());
//        assertEquals(StorageType.LOCAL, e.getStorageType());
//        assertEquals(AttachmentSource.USER, e.getSource());
//        assertFalse(e.isDeleted());
//        assertTrue(e.getUpdatedAt() > 0);
//    }

//    @Test
//    void promoteToServer_shouldChangeStorageType() {
//        AttachmentEntity e = AttachmentEntity.create(
//                UUID_ATT, USER_ID, UUID_NOTE,
//                AttachmentType.IMAGE, "image/jpeg",
//                "pocket_images/test.jpg", StorageType.LOCAL,
//                null, null, null, AttachmentSource.USER);
//
//        e.promoteToServer("uploads/1/abc.jpg");
//
//        assertEquals("uploads/1/abc.jpg", e.getStorageKey());
//        assertEquals(StorageType.SERVER, e.getStorageType());
//    }
//
//    @Test
//    void promoteToOss_shouldChangeStorageType() {
//        AttachmentEntity e = AttachmentEntity.create(
//                UUID_ATT, USER_ID, UUID_NOTE,
//                AttachmentType.IMAGE, "image/jpeg",
//                "pocket_images/test.jpg", StorageType.LOCAL,
//                null, null, null, AttachmentSource.USER);
//
//        e.promoteToOss("oss://bucket/key.jpg");
//
//        assertEquals("oss://bucket/key.jpg", e.getStorageKey());
//        assertEquals(StorageType.OSS, e.getStorageType());
//    }
}
