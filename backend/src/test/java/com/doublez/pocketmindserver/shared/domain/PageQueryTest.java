package com.doublez.pocketmindserver.shared.domain;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class PageQueryTest {

    @Test
    void shouldComputeOffset() {
        PageQuery q = new PageQuery(20, 3);
        assertEquals(20, q.limit());
        assertEquals(60, q.offset());
    }

    @Test
    void shouldRejectInvalidArgs() {
        assertThrows(IllegalArgumentException.class, () -> new PageQuery(0, 0));
        assertThrows(IllegalArgumentException.class, () -> new PageQuery(10, -1));
    }
}
