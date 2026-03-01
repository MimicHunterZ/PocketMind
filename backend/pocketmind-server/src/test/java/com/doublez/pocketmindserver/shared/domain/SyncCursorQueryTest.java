package com.doublez.pocketmindserver.shared.domain;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class SyncCursorQueryTest {

    @Test
    void shouldRejectNonPositiveLimit() {
        assertThrows(IllegalArgumentException.class, () -> new SyncCursorQuery(0L, 0));
    }
}
