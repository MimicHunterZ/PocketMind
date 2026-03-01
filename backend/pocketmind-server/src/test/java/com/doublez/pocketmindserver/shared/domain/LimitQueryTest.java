package com.doublez.pocketmindserver.shared.domain;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class LimitQueryTest {

    @Test
    void shouldRejectNonPositiveLimit() {
        assertThrows(IllegalArgumentException.class, () -> new LimitQuery(0));
    }
}
