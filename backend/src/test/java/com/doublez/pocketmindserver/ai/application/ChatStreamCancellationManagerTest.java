package com.doublez.pocketmindserver.ai.application;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ChatStreamCancellationManager 单元测试。
 */
class ChatStreamCancellationManagerTest {

    @Test
    void cancel_existingStream_shouldReturnTrue() {
        ChatStreamCancellationManager manager = new ChatStreamCancellationManager();
        String key = manager.buildKey(1L, UUID.randomUUID(), "req-1");

        manager.listenCancel(key).subscribe();

        boolean cancelled = manager.cancel(key, "test");
        assertTrue(cancelled);
    }

    @Test
    void cancel_missingStream_shouldReturnFalse() {
        ChatStreamCancellationManager manager = new ChatStreamCancellationManager();
        String key = manager.buildKey(1L, UUID.randomUUID(), "req-404");

        boolean cancelled = manager.cancel(key, "test");
        assertFalse(cancelled);
    }
}
