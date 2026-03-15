package com.doublez.pocketmind.framework.redis.core;

import com.doublez.pocketmind.framework.redis.config.PocketmindRedisConfig;
import com.doublez.pocketmind.framework.redis.config.RedissonLockAutoConfiguration;
import com.doublez.pocketmind.framework.redis.config.RedisServiceAutoConfiguration;
import com.doublez.pocketmind.framework.redis.lock.DistributedLockAspect;
import com.doublez.pocketmind.framework.redis.lock.DistributedLockFacade;
import org.junit.jupiter.api.Test;
import org.redisson.api.RedissonClient;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import com.fasterxml.jackson.databind.ObjectMapper;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class RedisAutoConfigurationTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(
                    PocketmindRedisConfig.class,
                    RedisServiceAutoConfiguration.class,
                    RedissonLockAutoConfiguration.class))
            .withBean(RedisConnectionFactory.class, () -> mock(RedisConnectionFactory.class))
            .withBean(RedissonClient.class, () -> mock(RedissonClient.class))
            .withBean(ObjectMapper.class, ObjectMapper::new)
            .withPropertyValues("spring.data.redis.host=127.0.0.1", "spring.data.redis.port=6379");

    @Test
    void shouldAutoConfigureRedisServiceWithoutComponentScan() {
        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(RedisService.class);
            assertThat(context).hasSingleBean(RedisKeyBuilder.class);
            assertThat(context).hasSingleBean(DistributedLockFacade.class);
            assertThat(context).hasSingleBean(DistributedLockAspect.class);
            assertThat(context).hasBean("pocketmindStringRedisTemplate");
        });
    }

    @Test
    void shouldUseConfiguredKeyPrefix() {
        contextRunner
                .withPropertyValues("pocketmind.redis.key-prefix=pm-test")
                .run(context -> {
                    RedisKeyBuilder keyBuilder = context.getBean(RedisKeyBuilder.class);
                    assertThat(keyBuilder.build("m", "b", "1")).isEqualTo("pm-test:m:b:1");
                });
    }
}
