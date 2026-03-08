package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.memory.domain.MemoryType;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * MemoryContextService 路径规则测试。
 */
class MemoryContextServiceTest {

    private final MemoryContextService service = new MemoryContextServiceImpl();

    @Test
    void shouldBuildPreferencesUri() {
        String actual = service.userMemoryByType(8L, MemoryType.PREFERENCES).value();
        assertEquals("pm://users/8/memories/preferences", actual);
    }
}
