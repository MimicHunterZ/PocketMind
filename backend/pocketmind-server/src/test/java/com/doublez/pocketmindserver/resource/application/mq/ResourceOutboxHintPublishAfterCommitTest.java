package com.doublez.pocketmindserver.resource.application.mq;

import org.junit.jupiter.api.Test;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.event.TransactionPhase;

import java.lang.reflect.Method;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;

/**
 * Resource Outbox Hint 事务发布约束测试（红阶段）。
 */
class ResourceOutboxHintPublishAfterCommitTest {

    /**
     * 用例A：事务提交成功时，append outbox 后应触发 hint 发布。
     */
    @Test
    void shouldPublishHintAfterOutboxAppendWhenTransactionCommitted() throws ClassNotFoundException {
        Class<?> hintListenerType = loadHintListenerType();
        Method afterCommitMethod = findAfterCommitListenerMethod(hintListenerType);

        assertNotNull(
                afterCommitMethod,
                "缺少 AFTER_COMMIT 事务监听方法：需要在 outbox append 成功提交后发布 hint"
        );
    }

    /**
     * 用例B：事务回滚时，不应触发 hint 发布。
     */
    @Test
    void shouldNotPublishHintWhenTransactionRolledBack() throws ClassNotFoundException {
        Class<?> hintListenerType = loadHintListenerType();
        Method afterCommitMethod = findAfterCommitListenerMethod(hintListenerType);

        assertNotNull(
                afterCommitMethod,
                "缺少 AFTER_COMMIT 事务监听方法：当前无法保证回滚场景不发布 hint"
        );

        TransactionalEventListener annotation =
                AnnotatedElementUtils.findMergedAnnotation(afterCommitMethod, TransactionalEventListener.class);
        assertNotNull(annotation, "AFTER_COMMIT 监听方法必须声明 @TransactionalEventListener");
        assertFalse(
                annotation.fallbackExecution(),
                "fallbackExecution 必须为 false，避免无事务/回滚路径误发布 hint"
        );
    }

    private Class<?> loadHintListenerType() throws ClassNotFoundException {
        List<String> candidates = List.of(
                "com.doublez.pocketmindserver.resource.application.mq.ResourceOutboxHintAfterCommitListener"
        );

        for (String candidate : candidates) {
            try {
                return Class.forName(candidate);
            } catch (ClassNotFoundException ignored) {
                // 继续尝试下一个候选类
            }
        }
        throw new ClassNotFoundException("未找到 Resource Outbox Hint 监听组件");
    }

    private Method findAfterCommitListenerMethod(Class<?> hintListenerType) {
        for (Method method : hintListenerType.getDeclaredMethods()) {
            TransactionalEventListener annotation =
                    AnnotatedElementUtils.findMergedAnnotation(method, TransactionalEventListener.class);
            if (annotation != null && annotation.phase() == TransactionPhase.AFTER_COMMIT) {
                return method;
            }
        }
        return null;
    }
}
