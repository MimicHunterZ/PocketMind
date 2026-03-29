package com.doublez.pocketmindserver.resource.application.mq;

import com.doublez.pocketmindserver.mq.ResourceOutboxMqConstants;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogProjector;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogRuntimeProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * Resource Outbox Hint 主消费监听器。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ResourceOutboxHintListener {

    private final ResourceCatalogProjector projector;
    private final ResourceCatalogRuntimeProperties runtimeProperties;

    @RabbitListener(
            queues = ResourceOutboxMqConstants.OUTBOX_HINT_QUEUE,
            containerFactory = ResourceOutboxMqConstants.OUTBOX_HINT_CONTAINER_FACTORY
    )
    public void onHint(ResourceOutboxHintEvent event) {
        projector.projectOnce(runtimeProperties.getProjectorBatchSize());
        log.debug("[ResourceOutboxHintListener] 收到 hint 并触发消费: eventUuid={}", event.eventUuid());
    }
}
