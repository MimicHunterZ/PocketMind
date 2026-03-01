package com.doublez.pocketmindserver.note.domain.tag;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class TagEntityTest {

    @Test
    void constructor_shouldRequireUuid() {
        assertThrows(NullPointerException.class, () -> new TagEntity(1L, null, 1L, "t", 1L, false));
    }

    @Test
    void constructor_shouldRequireName() {
        assertThrows(NullPointerException.class, () -> new TagEntity(1L, UUID.randomUUID(), 1L, null, 1L, false));
    }

    @Test
    void shouldExposeFields() {
        UUID uuid = UUID.randomUUID();
        TagEntity t = new TagEntity(7L, uuid, 2L, "t", 123L, false);
        assertEquals(7L, t.getId());
        assertEquals(uuid, t.getUuid());
        assertEquals(2L, t.getUserId());
        assertEquals("t", t.getName());
        assertEquals(123L, t.getUpdatedAt());
        assertFalse(t.isDeleted());
    }

    @Test
    void equals_shouldBeBasedOnUuid() {
        UUID uuid = UUID.randomUUID();
        TagEntity a = new TagEntity(10L, uuid, 1L, "A", 1L, false);
        TagEntity b = new TagEntity(11L, uuid, 2L, "B", 2L, true);
        assertEquals(a, b);
        assertEquals(a.hashCode(), b.hashCode());
    }

    @Test
    void create_shouldInitializeIdToZero() {
        TagEntity t = TagEntity.create(3L, "t");
        assertEquals(0L, t.getId());
        assertNotNull(t.getUuid());
        assertEquals(3L, t.getUserId());
        assertEquals("t", t.getName());
        assertTrue(t.getUpdatedAt() > 0);
        assertFalse(t.isDeleted());
    }
}
