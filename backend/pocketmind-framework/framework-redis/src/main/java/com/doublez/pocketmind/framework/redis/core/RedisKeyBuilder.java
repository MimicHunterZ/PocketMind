package com.doublez.pocketmind.framework.redis.core;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import org.springframework.util.StringUtils;

public class RedisKeyBuilder {

    private static final String SEPARATOR = ":";
    private final String prefix;

    public RedisKeyBuilder(String prefix) {
        if (!StringUtils.hasText(prefix)) {
            throw new IllegalArgumentException("Redis key prefix 不能为空");
        }
        this.prefix = prefix.trim();
    }

    public String build(String module, String biz, String id) {
        return join(prefix, module, biz, id);
    }

    public String join(String... segments) {
        if (segments == null || segments.length == 0) {
            throw new IllegalArgumentException("Redis key segments 不能为空");
        }

        List<String> normalized = new ArrayList<>(segments.length);
        for (String segment : segments) {
            if (segment == null) {
                continue;
            }
            String trimmed = segment.trim();
            if (!trimmed.isEmpty()) {
                normalized.add(trimmed);
            }
        }

        if (normalized.isEmpty()) {
            throw new IllegalArgumentException("Redis key segments 不能为空");
        }

        String key = String.join(SEPARATOR, normalized);
        if (key.indexOf(' ') >= 0) {
            throw new IllegalArgumentException("Redis key 不能包含空格");
        }
        return key;
    }

    public String append(String baseKey, String segment) {
        Objects.requireNonNull(baseKey, "baseKey 不能为空");
        return join(baseKey, segment);
    }

    public String prefix() {
        return prefix;
    }
}
