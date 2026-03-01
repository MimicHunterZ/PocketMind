package com.doublez.pocketmind.framework.redis.core;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RedisKeyBuilderTest {

    @Test
    void shouldBuildStandardPocketmindKey() {
        RedisKeyBuilder keyBuilder = new RedisKeyBuilder("pocketmind");
        String key = keyBuilder.build("module", "biz", "id-001");
        assertThat(key).isEqualTo("pocketmind:module:biz:id-001");
    }

    @Test
    void shouldRejectBlankSegments() {
        RedisKeyBuilder keyBuilder = new RedisKeyBuilder("pocketmind");
        assertThatThrownBy(() -> keyBuilder.join("   ", " "))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void shouldRejectBlankPrefix() {
        assertThatThrownBy(() -> new RedisKeyBuilder("   "))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
