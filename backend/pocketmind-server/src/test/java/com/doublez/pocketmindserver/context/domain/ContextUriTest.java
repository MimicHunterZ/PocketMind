package com.doublez.pocketmindserver.context.domain;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ContextUri 值对象单元测试。
 */
class ContextUriTest {

    @Test
    void shouldBuildUserResourcesRoot() {
        ContextUri uri = ContextUri.userResourcesRoot(7L);
        assertEquals("pm://users/7/resources", uri.value());
    }

    @Test
    void shouldBuildUserMemoriesRoot() {
        ContextUri uri = ContextUri.userMemoriesRoot(9L);
        assertEquals("pm://users/9/memories", uri.value());
    }

    @Test
    void shouldBuildTenantSkillRoot() {
        ContextUri uri = ContextUri.tenantAgentSkillsRoot("acme", "default-agent");
        assertEquals("pm://tenants/acme/agents/default-agent/skills", uri.value());
    }

    @Test
    void shouldBuildSessionRoot() {
        UUID sessionUuid = UUID.randomUUID();
        ContextUri uri = ContextUri.sessionRoot(sessionUuid);
        assertEquals("pm://sessions/" + sessionUuid, uri.value());
    }

    @Test
    void childShouldAppendSegment() {
        ContextUri uri = ContextUri.userResourcesRoot(1L).child("notes").child("abc");
        assertEquals("pm://users/1/resources/notes/abc", uri.value());
    }

    @Test
    void shouldRejectBlankValue() {
        assertThrows(IllegalArgumentException.class, () -> ContextUri.of(" "));
    }

    @Test
    void shouldRejectInvalidScheme() {
        assertThrows(IllegalArgumentException.class, () -> ContextUri.of("http://x"));
    }

    @Test
    void childShouldRejectInvalidSegment() {
        assertThrows(IllegalArgumentException.class,
                () -> ContextUri.userResourcesRoot(1L).child("/bad"));
    }
}
