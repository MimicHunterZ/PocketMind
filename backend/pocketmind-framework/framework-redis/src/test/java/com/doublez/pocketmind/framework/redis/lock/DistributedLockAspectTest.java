package com.doublez.pocketmind.framework.redis.lock;

import com.doublez.pocketmind.framework.redis.core.RedisKeyBuilder;
import com.doublez.pocketmind.framework.redis.exception.DistributedLockException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.aop.aspectj.annotation.AspectJProxyFactory;

import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DistributedLockAspectTest {

    private DistributedLockFacade distributedLockFacade;
    private OrderService orderService;

    @BeforeEach
    void setUp() {
        distributedLockFacade = mock(DistributedLockFacade.class);
        DistributedLockAspect aspect = new DistributedLockAspect(distributedLockFacade, new RedisKeyBuilder("pm"));

        AspectJProxyFactory proxyFactory = new AspectJProxyFactory(new OrderService());
        proxyFactory.setProxyTargetClass(true);
        proxyFactory.addAspect(aspect);
        orderService = proxyFactory.getProxy();
    }

    @Test
    void shouldLockAndUnlockWithSpelKey() {
        when(distributedLockFacade.tryLock(eq("pm:lock:order:1001"), eq(1L), eq(-1L), eq(TimeUnit.SECONDS)))
                .thenReturn(true);

        String result = orderService.process(1001L);

        assertThat(result).isEqualTo("ok-1001");
        verify(distributedLockFacade).unlock("pm:lock:order:1001");
    }

    @Test
    void shouldThrowWhenLockNotAcquired() {
        when(distributedLockFacade.tryLock(eq("pm:lock:order:1002"), eq(1L), eq(-1L), eq(TimeUnit.SECONDS)))
                .thenReturn(false);

        assertThatThrownBy(() -> orderService.process(1002L))
                .isInstanceOf(DistributedLockException.class)
                .hasMessageContaining("获取分布式锁失败");
    }

    static class OrderService {

        @DistributedLock(key = "'order:' + #orderId", waitTime = 1, leaseTime = -1, timeUnit = TimeUnit.SECONDS)
        public String process(Long orderId) {
            return "ok-" + orderId;
        }
    }
}
