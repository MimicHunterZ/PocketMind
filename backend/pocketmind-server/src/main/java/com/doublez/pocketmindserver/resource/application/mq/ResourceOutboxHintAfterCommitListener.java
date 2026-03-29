package com.doublez.pocketmindserver.resource.application.mq;

import com.doublez.pocketmindserver.resource.application.ResourceCatalogMetrics;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Resource Outbox Hint 事务提交后监听器。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ResourceOutboxHintAfterCommitListener {

    private final ResourceOutboxHintPublisher hintPublisher;
    private final ResourceOutboxHintCompensationPublisher compensationPublisher;
    private final ResourceCatalogMetrics metrics;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = false)
    public void onAfterCommit(ResourceOutboxHintEvent event) {
        try {
            hintPublisher.publish(event);
            log.debug("[ResourceOutboxHint] after commit 发布 hint: eventUuid={}, userId={}, resourceUuid={}",
                    event.eventUuid(), event.userId(), event.resourceUuid());
        } catch (Exception ex) {
            log.error("[ResourceOutboxHint] after commit 发布失败，进入补偿通道: eventUuid={}, error={}",
                    event.eventUuid(), ex.getMessage(), ex);
            metrics.incrementHintPublishFail();
            try {
                compensationPublisher.publishCompensation(event, ex.getMessage());
            } catch (Exception compensationEx) {
                log.error("[ResourceOutboxHint] 补偿发布失败: eventUuid={}, error={}",
                        event.eventUuid(), compensationEx.getMessage(), compensationEx);
            }
        }
    }
}
