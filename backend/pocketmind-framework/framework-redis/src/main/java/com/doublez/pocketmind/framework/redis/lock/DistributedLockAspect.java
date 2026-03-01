package com.doublez.pocketmind.framework.redis.lock;

import com.doublez.pocketmind.framework.redis.core.RedisKeyBuilder;
import com.doublez.pocketmind.framework.redis.exception.DistributedLockException;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.context.expression.MethodBasedEvaluationContext;
import org.springframework.core.DefaultParameterNameDiscoverer;
import org.springframework.core.ParameterNameDiscoverer;
import org.springframework.expression.Expression;
import org.springframework.expression.ExpressionParser;
import org.springframework.expression.spel.standard.SpelExpressionParser;
import org.springframework.util.StringUtils;

import java.lang.reflect.Method;

@Aspect
public class DistributedLockAspect {

    private final DistributedLockFacade distributedLockFacade;
    private final RedisKeyBuilder redisKeyBuilder;
    private final ParameterNameDiscoverer parameterNameDiscoverer = new DefaultParameterNameDiscoverer();
    private final ExpressionParser expressionParser = new SpelExpressionParser();

    public DistributedLockAspect(DistributedLockFacade distributedLockFacade, RedisKeyBuilder redisKeyBuilder) {
        this.distributedLockFacade = distributedLockFacade;
        this.redisKeyBuilder = redisKeyBuilder;
    }

    @Around("@annotation(distributedLock)")
    public Object around(ProceedingJoinPoint joinPoint, DistributedLock distributedLock) throws Throwable {
        String resolvedKey = resolveKey(joinPoint, distributedLock.key());
        String lockKey = redisKeyBuilder.join(redisKeyBuilder.prefix(), "lock", resolvedKey);

        boolean acquired = distributedLockFacade.tryLock(
                lockKey,
                distributedLock.waitTime(),
                distributedLock.leaseTime(),
                distributedLock.timeUnit());
        if (!acquired) {
            throw new DistributedLockException("获取分布式锁失败, lockKey=" + lockKey);
        }

        try {
            return joinPoint.proceed();
        } finally {
            distributedLockFacade.unlock(lockKey);
        }
    }

    private String resolveKey(ProceedingJoinPoint joinPoint, String keyExpression) {
        if (!StringUtils.hasText(keyExpression)) {
            throw new IllegalArgumentException("DistributedLock key 不能为空");
        }

        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        Method method = signature.getMethod();
        MethodBasedEvaluationContext context = new MethodBasedEvaluationContext(
                joinPoint.getTarget(),
                method,
                joinPoint.getArgs(),
                parameterNameDiscoverer);

        if (keyExpression.contains("#") || keyExpression.startsWith("T(")) {
            Expression expression = expressionParser.parseExpression(keyExpression);
            Object value = expression.getValue(context);
            if (value == null) {
                throw new IllegalArgumentException("DistributedLock key 表达式结果不能为空");
            }
            String key = String.valueOf(value).trim();
            if (!StringUtils.hasText(key)) {
                throw new IllegalArgumentException("DistributedLock key 表达式结果不能为空字符串");
            }
            return key;
        }

        return keyExpression.trim();
    }
}