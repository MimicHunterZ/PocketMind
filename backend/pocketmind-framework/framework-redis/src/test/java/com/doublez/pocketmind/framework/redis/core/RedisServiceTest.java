package com.doublez.pocketmind.framework.redis.core;

import com.doublez.pocketmind.framework.redis.exception.RedisCacheException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.HashOperations;
import org.springframework.data.redis.core.ListOperations;
import org.springframework.data.redis.core.SetOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.data.redis.core.script.RedisScript;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class RedisServiceTest {

    private StringRedisTemplate redisTemplate;
    private ValueOperations<String, String> valueOperations;
    private HashOperations<String, Object, Object> hashOperations;
    private ListOperations<String, String> listOperations;
    private SetOperations<String, String> setOperations;
    private ZSetOperations<String, String> zSetOperations;
    private RedisService redisService;
    private ObjectMapper objectMapper;
    @BeforeEach
    void setUp() {
        redisTemplate = mock(StringRedisTemplate.class);
        valueOperations = mock(ValueOperations.class);
        hashOperations = mock(HashOperations.class);
        listOperations = mock(ListOperations.class);
        setOperations = mock(SetOperations.class);
        zSetOperations = mock(ZSetOperations.class);

        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(redisTemplate.opsForHash()).thenReturn(hashOperations);
        when(redisTemplate.opsForList()).thenReturn(listOperations);
        when(redisTemplate.opsForSet()).thenReturn(setOperations);
        when(redisTemplate.opsForZSet()).thenReturn(zSetOperations);

        redisService = new RedisService(redisTemplate,objectMapper);
    }

    @Test
    void shouldSupportGenericGetAndBatchOperations() {
        when(valueOperations.get("user:1")).thenReturn("alice");
        when(valueOperations.multiGet(List.of("k1", "k2"))).thenReturn(List.of("v1", "v2"));

        String value = redisService.get("user:1");
        List<String> values = redisService.multiGet(List.of("k1", "k2"));
        redisService.multiSet(Map.of("k1", "v1", "k2", "v2"));

        assertThat(value).isEqualTo("alice");
        assertThat(values).containsExactly("v1", "v2");
    }

    @Test
    void shouldSupportHashListSetAndZSetOperations() {
        when(hashOperations.get("h", "f1")).thenReturn("v1");
        when(listOperations.range("list", 0, -1)).thenReturn(List.of("a", "b"));
        when(setOperations.members("set")).thenReturn(Set.of("x", "y"));
        when(zSetOperations.reverseRange("rank", 0, 9)).thenReturn(Set.of("u1", "u2"));

        redisService.hset("h", "f1", "v1");
        String hValue = redisService.hget("h", "f1");
        List<String> list = redisService.lrange("list", 0, -1);
        Set<String> set = redisService.smembers("set");
        Set<String> rank = redisService.zrevrange("rank", 0, 9);

        assertThat(hValue).isEqualTo("v1");
        assertThat(list).containsExactly("a", "b");
        assertThat(set).contains("x", "y");
        assertThat(rank).contains("u1", "u2");
    }

    @Test
    void shouldSupportCounterOperations() {
        when(valueOperations.increment("counter", 2)).thenReturn(5L);
        when(valueOperations.increment("counter", -3)).thenReturn(2L);

        long increased = redisService.increment("counter", 2);
        long decreased = redisService.decrement("counter", 3);

        assertThat(increased).isEqualTo(5L);
        assertThat(decreased).isEqualTo(2L);
    }

    @Test
    void shouldExecuteLuaScript() {
        when(redisTemplate.execute(any(RedisScript.class), eq(List.of("k1")), (Object[]) any())).thenReturn(7L);

        Long result = redisService.executeLua("return 7", List.of("k1"), List.of("a1"), Long.class);

        assertThat(result).isEqualTo(7L);
    }

    @Test
    void shouldThrowAndProvideSafeFallbackOnRedisFailure() {
        when(valueOperations.get(anyString())).thenThrow(new RuntimeException("redis down"));

        assertThatThrownBy(() -> redisService.get("k1"))
                .isInstanceOf(RedisCacheException.class);

        Optional<String> safeValue = redisService.getSafe("k1");
        assertThat(safeValue).isEmpty();
    }
}
