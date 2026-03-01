package com.doublez.pocketmind.framework.redis.lock;

import com.doublez.pocketmind.framework.redis.exception.DistributedLockException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;

import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DistributedLockFacadeTest {

    private RedissonClient redissonClient;
    private RLock rLock;
    private DistributedLockFacade distributedLockFacade;

    @BeforeEach
    void setUp() {
        redissonClient = mock(RedissonClient.class);
        rLock = mock(RLock.class);
        when(redissonClient.getLock("pm:lock:order:1")).thenReturn(rLock);
        distributedLockFacade = new DistributedLockFacade(redissonClient);
    }

    @Test
    void shouldUseWatchdogWhenLeaseTimeIsNegative() throws Exception {
        when(rLock.tryLock(2, TimeUnit.SECONDS)).thenReturn(true);

        boolean acquired = distributedLockFacade.tryLock("pm:lock:order:1", 2, -1, TimeUnit.SECONDS);

        assertThat(acquired).isTrue();
        verify(rLock).tryLock(2, TimeUnit.SECONDS);
    }

    @Test
    void shouldUseFixedLeaseWhenLeaseTimePositive() throws Exception {
        when(rLock.tryLock(2, 10, TimeUnit.SECONDS)).thenReturn(true);

        boolean acquired = distributedLockFacade.tryLock("pm:lock:order:1", 2, 10, TimeUnit.SECONDS);

        assertThat(acquired).isTrue();
        verify(rLock).tryLock(2, 10, TimeUnit.SECONDS);
    }

    @Test
    void shouldUnlockOnlyWhenHeldByCurrentThread() {
        when(rLock.isHeldByCurrentThread()).thenReturn(true);

        distributedLockFacade.unlock("pm:lock:order:1");

        verify(rLock).unlock();
    }

    @Test
    void shouldWrapInterruptedException() throws Exception {
        when(rLock.tryLock(1, TimeUnit.SECONDS)).thenThrow(new InterruptedException("interrupted"));

        assertThatThrownBy(() -> distributedLockFacade.tryLock("pm:lock:order:1", 1, -1, TimeUnit.SECONDS))
                .isInstanceOf(DistributedLockException.class)
                .hasMessageContaining("被中断");
    }
}
