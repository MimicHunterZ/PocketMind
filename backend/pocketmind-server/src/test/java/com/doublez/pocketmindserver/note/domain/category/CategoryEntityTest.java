package com.doublez.pocketmindserver.note.domain.category;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class CategoryEntityTest {

    @Test
    void create_shouldRequireName() {
        assertThrows(NullPointerException.class, () -> CategoryEntity.create(1L, null));
    }

    @Test
    void create_shouldInitializeIdToZero() {
        CategoryEntity c = CategoryEntity.create(1L, "默认");
        assertEquals(0L, c.getId());
        assertNotNull(c.getUuid());
        assertEquals(1L, c.getUserId());
        assertEquals("默认", c.getName());
        assertTrue(c.getUpdatedAt() > 0);
        assertFalse(c.isDeleted());
    }

    @Test
    void equals_shouldBeBasedOnUuid() {
        UUID uuid = UUID.randomUUID();
        CategoryEntity a = new CategoryEntity(10L, uuid, 1L, "A", 1L, false);
        CategoryEntity b = new CategoryEntity(11L, uuid, 2L, "B", 2L, true);
        assertEquals(a, b);
        assertEquals(a.hashCode(), b.hashCode());
    }
}
