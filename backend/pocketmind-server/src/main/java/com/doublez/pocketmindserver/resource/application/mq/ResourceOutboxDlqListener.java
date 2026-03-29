package com.doublez.pocketmindserver.resource.application.mq;

import com.doublez.pocketmindserver.mq.ResourceOutboxMqConstants;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogMetrics;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogProjector;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogRuntimeProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/**
 * Resource Outbox Hint 死信补偿监听器。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ResourceOutboxDlqListener {

    private final ResourceCatalogProjector projector;
    private final ResourceCatalogRuntimeProperties runtimeProperties;
    private final ResourceCatalogMetrics metrics;
    private final ConcurrentMap<UUID, Integer> replayCounter = new ConcurrentHashMap<>();

    @RabbitListener(
            queues = ResourceOutboxMqConstants.OUTBOX_HINT_DLQ_QUEUE,
            containerFactory = ResourceOutboxMqConstants.OUTBOX_HINT_DLQ_CONTAINER_FACTORY
    )
    public void onDlq(ResourceOutboxHintEvent event) {
        int current = replayCounter.merge(event.eventUuid(), 1, Integer::sum);
        if (current > runtimeProperties.getHintDlqMaxReplay()) {
            log.error("[ResourceOutboxDlqListener] 超过 DLQ 最大重放次数，停止重放: eventUuid={}, attempts={}",
                    event.eventUuid(), current);
            metrics.incrementDlqReplayFail();
            replayCounter.remove(event.eventUuid());
            return;
        }
        projector.projectOnce(runtimeProperties.getProjectorBatchSize());
        metrics.incrementDlqReplaySuccess();
        log.warn("[ResourceOutboxDlqListener] 收到 DLQ 消息并触发补偿消费: eventUuid={}, attempts={}",
                event.eventUuid(), current);
    }
}
