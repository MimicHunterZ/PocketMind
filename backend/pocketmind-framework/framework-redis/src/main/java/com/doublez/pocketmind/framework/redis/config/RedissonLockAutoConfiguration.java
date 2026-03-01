package com.doublez.pocketmind.framework.redis.config;

import com.doublez.pocketmind.framework.redis.core.RedisKeyBuilder;
import com.doublez.pocketmind.framework.redis.lock.DistributedLockAspect;
import com.doublez.pocketmind.framework.redis.lock.DistributedLockFacade;
import org.redisson.Redisson;
import org.redisson.api.RedissonClient;
import org.redisson.config.Config;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.data.redis.autoconfigure.DataRedisProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.util.CollectionUtils;
import org.springframework.util.StringUtils;

import java.time.Duration;
import java.util.List;

@AutoConfiguration(after = PocketmindRedisConfig.class)
@ConditionalOnClass(RedissonClient.class)
@ConditionalOnBean(RedisConnectionFactory.class)
@ConditionalOnProperty(name = "pocketmind.redis.enabled", havingValue = "true", matchIfMissing = true)
public class RedissonLockAutoConfiguration {

    @Bean(destroyMethod = "shutdown")
    @ConditionalOnMissingBean(RedissonClient.class)
    public RedissonClient redissonClient(DataRedisProperties redisProperties) {
        Config config = new Config();

        if (isCluster(redisProperties)) {
            List<String> nodeAddresses = redisProperties.getCluster().getNodes().stream()
                    .map(node -> toAddress(node, isSslEnabled(redisProperties)))
                    .toList();

            config.useClusterServers()
                    .addNodeAddress(nodeAddresses.toArray(new String[0]));
            applyCommon(config.useClusterServers(), redisProperties);
        } else {
                String host = StringUtils.hasText(redisProperties.getHost()) ? redisProperties.getHost() : "127.0.0.1";
                int port = redisProperties.getPort() <= 0 ? 6379 : redisProperties.getPort();
                String address = StringUtils.hasText(redisProperties.getUrl())
                    ? toAddress(redisProperties.getUrl(), isSslEnabled(redisProperties))
                    : toAddress(host + ":" + port, isSslEnabled(redisProperties));

            config.useSingleServer()
                    .setAddress(address)
                    .setDatabase(redisProperties.getDatabase());
            applyCommon(config.useSingleServer(), redisProperties);
        }

        return Redisson.create(config);
    }

    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnBean(RedissonClient.class)
    public DistributedLockFacade distributedLockFacade(RedissonClient redissonClient) {
        return new DistributedLockFacade(redissonClient);
    }

    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnBean({DistributedLockFacade.class, RedisKeyBuilder.class})
    public DistributedLockAspect distributedLockAspect(DistributedLockFacade distributedLockFacade,
                                                       RedisKeyBuilder redisKeyBuilder) {
        return new DistributedLockAspect(distributedLockFacade, redisKeyBuilder);
    }

    private static boolean isCluster(DataRedisProperties redisProperties) {
        return redisProperties.getCluster() != null && !CollectionUtils.isEmpty(redisProperties.getCluster().getNodes());
    }

    private static boolean isSslEnabled(DataRedisProperties redisProperties) {
        return redisProperties.getSsl() != null && redisProperties.getSsl().isEnabled();
    }

    private static String toAddress(String hostPort, boolean sslEnabled) {
        if (hostPort.startsWith("redis://") || hostPort.startsWith("rediss://")) {
            return hostPort;
        }
        return (sslEnabled ? "rediss://" : "redis://") + hostPort;
    }

    private static void applyCommon(org.redisson.config.BaseConfig<?> baseConfig, DataRedisProperties redisProperties) {
        if (StringUtils.hasText(redisProperties.getUsername())) {
            baseConfig.setUsername(redisProperties.getUsername());
        }
        if (StringUtils.hasText(redisProperties.getPassword())) {
            baseConfig.setPassword(redisProperties.getPassword());
        }
        Duration connectTimeout = redisProperties.getConnectTimeout();
        if (connectTimeout != null && !connectTimeout.isNegative() && !connectTimeout.isZero()) {
            baseConfig.setConnectTimeout((int) connectTimeout.toMillis());
        }
        Duration timeout = redisProperties.getTimeout();
        if (timeout != null && !timeout.isNegative() && !timeout.isZero()) {
            baseConfig.setTimeout((int) timeout.toMillis());
        }
    }
}