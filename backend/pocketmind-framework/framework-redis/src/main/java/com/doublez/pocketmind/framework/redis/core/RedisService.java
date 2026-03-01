package com.doublez.pocketmind.framework.redis.core;

import com.doublez.pocketmind.framework.redis.exception.RedisCacheException;
import com.fasterxml.jackson.core.JsonProcessingException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.util.CollectionUtils;
import org.springframework.util.StringUtils;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Supplier;

@Slf4j
public class RedisService {

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    public RedisService(StringRedisTemplate redisTemplate, ObjectMapper objectMapper) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    /**
     * 写入 Java 对象
     */
    public <T> boolean setObject(String key, T domainObj, Duration ttl) {
        if (domainObj == null) {
            return false;
        }
        try {
            // 在底层完成纯净的 JSON 转换
            String jsonValue = objectMapper.writeValueAsString(domainObj);
            return set(key, jsonValue, ttl);
        } catch (JsonProcessingException e) {
            log.error("Redis 序列化对象失败, key={}, class={}", key, domainObj.getClass().getName(), e);
            throw new RedisCacheException("JSON 序列化失败", e);
        }
    }

    /**
     * 读取并转换为指定的 Java 对象
     */
    public <T> T getObject(String key, Class<T> targetClass) {
        String jsonValue = get(key);
        if (!StringUtils.hasText(jsonValue)) {
            return null;
        }
        try {
            return objectMapper.readValue(jsonValue, targetClass);
        } catch (JsonProcessingException e) {
            log.error("Redis 反序列化对象失败, key={}, targetClass={}", key, targetClass.getName(), e);
            throw new RedisCacheException("JSON 反序列化失败", e);
        }
    }

    /**
     * 针对 List<T> 泛型集合的专属读取方法（解决泛型擦除痛点）
     */
    public <T> List<T> getList(String key, Class<T> elementClass) {
        String jsonValue = get(key);
        if (!StringUtils.hasText(jsonValue)) {
            return Collections.emptyList();
        }
        try {
            // 利用 ObjectMapper 构建带泛型的 JavaType
            JavaType javaType = objectMapper.getTypeFactory().constructParametricType(List.class, elementClass);
            return objectMapper.readValue(jsonValue, javaType);
        } catch (JsonProcessingException e) {
            log.error("Redis 反序列化 List 失败, key={}, elementClass={}", key, elementClass.getName(), e);
            throw new RedisCacheException("JSON List 反序列化失败", e);
        }
    }

    public boolean set(String key, String value) {
        execute("set", key, () -> {
            redisTemplate.opsForValue().set(key, value);
            return true;
        });
        return true;
    }

    public boolean set(String key, String value, Duration ttl) {
        execute("setWithTtl", key, () -> {
            if (ttl == null || ttl.isNegative() || ttl.isZero()) {
                redisTemplate.opsForValue().set(key, value);
            } else {
                redisTemplate.opsForValue().set(key, value, ttl);
            }
            return true;
        });
        return true;
    }

    public boolean setSafe(String key, String value) {
        try {
            return set(key, value);
        } catch (RedisCacheException e) {
            log.warn("Redis setSafe 失败, key={}, error={}", key, e.getMessage());
            return false;
        }
    }

    public boolean setSafe(String key, String value, Duration ttl) {
        try {
            return set(key, value, ttl);
        } catch (RedisCacheException e) {
            log.warn("Redis setSafe with ttl 失败, key={}, error={}", key, e.getMessage());
            return false;
        }
    }

    public String get(String key) {
        return execute("get", key, () -> redisTemplate.opsForValue().get(key));
    }

    public Optional<String> getOptional(String key) {
        return Optional.ofNullable(get(key));
    }

    public Optional<String> getSafe(String key) {
        try {
            return getOptional(key);
        } catch (RedisCacheException e) {
            log.warn("Redis getSafe 失败, key={}, error={}", key, e.getMessage());
            return Optional.empty();
        }
    }

    public boolean del(String key) {
        return execute("del", key, () -> Boolean.TRUE.equals(redisTemplate.delete(key)));
    }

    public long del(Collection<String> keys) {
        if (CollectionUtils.isEmpty(keys)) {
            return 0;
        }
        Long deleted = execute("delBatch", String.join(",", keys), () -> redisTemplate.delete(keys));
        return deleted == null ? 0 : deleted;
    }

    public boolean delSafe(String key) {
        try {
            return del(key);
        } catch (RedisCacheException e) {
            log.warn("Redis delSafe 失败, key={}, error={}", key, e.getMessage());
            return false;
        }
    }

    public boolean hasKey(String key) {
        return execute("hasKey", key, () -> Boolean.TRUE.equals(redisTemplate.hasKey(key)));
    }

    public boolean hasKeySafe(String key) {
        try {
            return hasKey(key);
        } catch (RedisCacheException e) {
            log.warn("Redis hasKeySafe 失败, key={}, error={}", key, e.getMessage());
            return false;
        }
    }

    public boolean setExpire(String key, Duration ttl) {
        if (ttl == null || ttl.isNegative() || ttl.isZero()) {
            return false;
        }
        return execute("expire", key, () -> Boolean.TRUE.equals(redisTemplate.expire(key, ttl)));
    }

    public boolean setExpireSafe(String key, Duration ttl) {
        try {
            return setExpire(key, ttl);
        } catch (RedisCacheException e) {
            log.warn("Redis expireSafe 失败, key={}, error={}", key, e.getMessage());
            return false;
        }
    }

    public long increment(String key, long delta) {
        Long result = execute("increment", key, () -> redisTemplate.opsForValue().increment(key, delta));
        return result == null ? 0 : result;
    }

    public long decrement(String key, long delta) {
        Long result = execute("decrement", key, () -> redisTemplate.opsForValue().increment(key, -Math.abs(delta)));
        return result == null ? 0 : result;
    }

    public List<String> multiGet(Collection<String> keys) {
        if (CollectionUtils.isEmpty(keys)) {
            return Collections.emptyList();
        }
        List<String> values = execute("multiGet", String.join(",", keys),
                () -> redisTemplate.opsForValue().multiGet(keys));
        return values == null ? Collections.emptyList() : values;
    }

    public void multiSet(Map<String, String> map) {
        if (CollectionUtils.isEmpty(map)) {
            return;
        }
        execute("multiSet", String.join(",", map.keySet()), () -> {
            redisTemplate.opsForValue().multiSet(map);
            return true;
        });
    }

    public void hset(String key, String field, String value) {
        execute("hset", key, () -> {
            redisTemplate.opsForHash().put(key, field, value);
            return true;
        });
    }

    public String hget(String key, String field) {
        Object value = execute("hget", key, () -> redisTemplate.opsForHash().get(key, field));
        return value == null ? null : value.toString();
    }

    public void hmset(String key, Map<String, String> map) {
        if (CollectionUtils.isEmpty(map)) {
            return;
        }
        execute("hmset", key, () -> {
            redisTemplate.opsForHash().putAll(key, map);
            return true;
        });
    }

    public Map<String, String> hgetAll(String key) {
        Map<Object, Object> result = execute("hgetAll", key, () -> redisTemplate.opsForHash().entries(key));
        if (result == null || result.isEmpty()) {
            return Collections.emptyMap();
        }
        return result.entrySet()
                .stream()
                .collect(java.util.stream.Collectors.toMap(
                        entry -> entry.getKey() == null ? "" : entry.getKey().toString(),
                        entry -> entry.getValue() == null ? "" : entry.getValue().toString()
                ));
    }

    public long lpush(String key, String value) {
        Long result = execute("lpush", key, () -> redisTemplate.opsForList().leftPush(key, value));
        return result == null ? 0 : result;
    }

    public long rpush(String key, String value) {
        Long result = execute("rpush", key, () -> redisTemplate.opsForList().rightPush(key, value));
        return result == null ? 0 : result;
    }

    public String lpop(String key) {
        return execute("lpop", key, () -> redisTemplate.opsForList().leftPop(key));
    }

    public String rpop(String key) {
        return execute("rpop", key, () -> redisTemplate.opsForList().rightPop(key));
    }

    public List<String> lrange(String key, long start, long end) {
        List<String> result = execute("lrange", key, () -> redisTemplate.opsForList().range(key, start, end));
        return result == null ? Collections.emptyList() : result;
    }

    public long sadd(String key, String... values) {
        if (values == null || values.length == 0) {
            return 0;
        }
        Long result = execute("sadd", key, () -> redisTemplate.opsForSet().add(key, values));
        return result == null ? 0 : result;
    }

    public boolean sismember(String key, String value) {
        return execute("sismember", key, () -> Boolean.TRUE.equals(redisTemplate.opsForSet().isMember(key, value)));
    }

    public Set<String> smembers(String key) {
        Set<String> result = execute("smembers", key, () -> redisTemplate.opsForSet().members(key));
        return result == null ? Collections.emptySet() : result;
    }

    public boolean zadd(String key, String value, double score) {
        return execute("zadd", key, () -> Boolean.TRUE.equals(redisTemplate.opsForZSet().add(key, value, score)));
    }

    public Set<String> zrange(String key, long start, long end) {
        Set<String> result = execute("zrange", key, () -> redisTemplate.opsForZSet().range(key, start, end));
        return result == null ? Collections.emptySet() : result;
    }

    public Set<String> zrevrange(String key, long start, long end) {
        Set<String> result = execute("zrevrange", key, () -> redisTemplate.opsForZSet().reverseRange(key, start, end));
        return result == null ? Collections.emptySet() : result;
    }

    public <T> T executeLua(String script, List<String> keys, List<?> args, Class<T> resultType) {
        if (!StringUtils.hasText(script)) {
            throw new IllegalArgumentException("Lua 脚本不能为空");
        }
        DefaultRedisScript<T> redisScript = new DefaultRedisScript<>();
        redisScript.setScriptText(script);
        redisScript.setResultType(resultType);

        List<String> evalKeys = keys == null ? Collections.emptyList() : keys;
        Object[] evalArgs = args == null
            ? new Object[0]
            : args.stream().map(arg -> arg == null ? "" : arg.toString()).toArray();
        return execute("lua", String.join(",", evalKeys), () -> redisTemplate.execute(redisScript, evalKeys, evalArgs));
    }

    private <T> T execute(String action, String key, Supplier<T> supplier) {
        try {
            return supplier.get();
        } catch (Exception e) {
            throw new RedisCacheException("Redis " + action + " 失败, key=" + key, e);
        }
    }
}
