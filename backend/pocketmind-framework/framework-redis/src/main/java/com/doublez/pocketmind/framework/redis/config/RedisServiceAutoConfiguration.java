package com.doublez.pocketmind.framework.redis.config;

import com.doublez.pocketmind.framework.redis.core.RedisKeyBuilder;
import com.doublez.pocketmind.framework.redis.core.RedisService;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.core.env.Environment;
import org.springframework.util.StringUtils;
import com.fasterxml.jackson.databind.ObjectMapper;

@AutoConfiguration(after = PocketmindRedisConfig.class)
@ConditionalOnClass(StringRedisTemplate.class)
@ConditionalOnBean(name = "pocketmindStringRedisTemplate")
@ConditionalOnProperty(name = "pocketmind.redis.enabled", havingValue = "true", matchIfMissing = true)
@EnableConfigurationProperties(PocketmindRedisProperties.class)
public class RedisServiceAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public RedisService redisService(
            @Qualifier("pocketmindStringRedisTemplate") StringRedisTemplate redisTemplate,
            ObjectMapper objectMapper
    ) {
        return new RedisService(redisTemplate, objectMapper);
    }

    @Bean
    @ConditionalOnMissingBean
    public RedisKeyBuilder redisKeyBuilder(PocketmindRedisProperties properties, Environment environment) {
        String prefix = properties.getKeyPrefix();
        if (!StringUtils.hasText(prefix)) {
            prefix = environment.getProperty("spring.application.name", "pocketmind");
        }
        return new RedisKeyBuilder(prefix);
    }
}
