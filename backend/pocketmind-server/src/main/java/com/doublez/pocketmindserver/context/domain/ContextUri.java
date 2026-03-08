package com.doublez.pocketmindserver.context.domain;

import java.util.Objects;
import java.util.UUID;

/**
 * PocketMind 上下文 URI 值对象。
 */
public record ContextUri(String value) {

    private static final String SCHEME = "pm://";

    public ContextUri {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("context uri 不能为空");
        }
        if (!value.startsWith(SCHEME)) {
            throw new IllegalArgumentException("context uri 必须以 pm:// 开头");
        }
    }

    public static ContextUri of(String value) {
        return new ContextUri(value);
    }

    public static ContextUri userResourcesRoot(long userId) {
        return of("pm://users/" + userId + "/resources");
    }

    public static ContextUri userMemoriesRoot(long userId) {
        return of("pm://users/" + userId + "/memories");
    }

    public static ContextUri tenantAgentSkillsRoot(String tenantKey, String agentKey) {
        return of("pm://tenants/" + normalizeSegment(tenantKey) + "/agents/" + normalizeSegment(agentKey) + "/skills");
    }

    public static ContextUri sessionRoot(UUID sessionUuid) {
        Objects.requireNonNull(sessionUuid, "sessionUuid 不能为空");
        return of("pm://sessions/" + sessionUuid);
    }

    public ContextUri child(String segment) {
        return of(value + "/" + normalizeSegment(segment));
    }

    private static String normalizeSegment(String segment) {
        if (segment == null || segment.isBlank()) {
            throw new IllegalArgumentException("uri segment 不能为空");
        }
        String normalized = segment.trim().replace('\\', '/');
        if (normalized.contains("//")) {
            throw new IllegalArgumentException("uri segment 非法：不能包含空路径段");
        }
        if (normalized.startsWith("/") || normalized.endsWith("/")) {
            throw new IllegalArgumentException("uri segment 非法：不能以 / 开头或结尾");
        }
        return normalized;
    }
}
