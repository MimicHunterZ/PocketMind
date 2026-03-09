package com.doublez.pocketmindserver.context.domain;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

/**
 * SpaceType 与 Visibility 枚举基本覆盖测试。
 */
class SpaceModelTest {

    // ─── SpaceType ──────────────────────────────────────────────

    @Test
    void spaceType_应包含五层空间() {
        assertEquals(5, SpaceType.values().length);
        assertNotNull(SpaceType.valueOf("SYSTEM"));
        assertNotNull(SpaceType.valueOf("TENANT"));
        assertNotNull(SpaceType.valueOf("AGENT"));
        assertNotNull(SpaceType.valueOf("USER"));
        assertNotNull(SpaceType.valueOf("SESSION"));
    }

    @Test
    void spaceType_顺序从系统到会话() {
        SpaceType[] values = SpaceType.values();
        assertEquals(SpaceType.SYSTEM, values[0]);
        assertEquals(SpaceType.SESSION, values[4]);
    }

    // ─── Visibility ─────────────────────────────────────────────

    @Test
    void visibility_应包含四种可见性() {
        assertEquals(4, Visibility.values().length);
        assertNotNull(Visibility.valueOf("PRIVATE"));
        assertNotNull(Visibility.valueOf("SESSION_ONLY"));
        assertNotNull(Visibility.valueOf("TENANT_SHARED"));
        assertNotNull(Visibility.valueOf("SYSTEM_SHARED"));
    }

    @Test
    void visibility_默认值为PRIVATE() {
        // PRIVATE 应在第一位，作为最常用的默认值
        assertEquals(Visibility.PRIVATE, Visibility.values()[0]);
    }
}
