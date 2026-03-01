package com.doublez.pocketmind.framework.redis.config;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;

@AutoConfiguration
@ConditionalOnClass(StringRedisTemplate.class)
@ConditionalOnProperty(name = "pocketmind.redis.enabled", havingValue = "true", matchIfMissing = true)
public class PocketmindRedisConfig {

    @Bean(name = "pocketmindStringRedisTemplate")
    @ConditionalOnMissingBean(name = "pocketmindStringRedisTemplate")
    public StringRedisTemplate pocketmindStringRedisTemplate(RedisConnectionFactory redisConnectionFactory) {
        return new StringRedisTemplate(redisConnectionFactory);
    }
}
