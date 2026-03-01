package com.doublez.pocketmind.framework.redis.lock;

import com.doublez.pocketmind.framework.redis.exception.DistributedLockException;
import lombok.extern.slf4j.Slf4j;
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.springframework.util.StringUtils;

import java.util.concurrent.TimeUnit;

@Slf4j
public class DistributedLockFacade {

    private final RedissonClient redissonClient;

    public DistributedLockFacade(RedissonClient redissonClient) {
        this.redissonClient = redissonClient;
    }

    public boolean tryLock(String lockKey, long waitTime, long leaseTime, TimeUnit timeUnit) {
        validate(lockKey, timeUnit);
        try {
            RLock lock = redissonClient.getLock(lockKey);
            if (leaseTime <= 0) {
                return lock.tryLock(waitTime, timeUnit);
            }
            return lock.tryLock(waitTime, leaseTime, timeUnit);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new DistributedLockException("分布式锁等待被中断, lockKey=" + lockKey, e);
        } catch (Exception e) {
            throw new DistributedLockException("分布式锁获取失败, lockKey=" + lockKey, e);
        }
    }

    public void lock(String lockKey) {
        validate(lockKey, TimeUnit.SECONDS);
        try {
            redissonClient.getLock(lockKey).lock();
        } catch (Exception e) {
            throw new DistributedLockException("分布式锁加锁失败, lockKey=" + lockKey, e);
        }
    }

    public void unlock(String lockKey) {
        validate(lockKey, TimeUnit.SECONDS);
        try {
            RLock lock = redissonClient.getLock(lockKey);
            if (lock.isHeldByCurrentThread()) {
                lock.unlock();
                return;
            }
            log.warn("当前线程未持有锁，忽略解锁请求, lockKey={}", lockKey);
        } catch (Exception e) {
            throw new DistributedLockException("分布式锁解锁失败, lockKey=" + lockKey, e);
        }
    }

    private void validate(String lockKey, TimeUnit timeUnit) {
        if (!StringUtils.hasText(lockKey)) {
            throw new IllegalArgumentException("lockKey 不能为空");
        }
        if (timeUnit == null) {
            throw new IllegalArgumentException("timeUnit 不能为空");
        }
    }
}