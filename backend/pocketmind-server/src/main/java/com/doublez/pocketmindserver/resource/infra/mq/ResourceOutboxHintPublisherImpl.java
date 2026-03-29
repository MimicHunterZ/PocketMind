package com.doublez.pocketmindserver.resource.infra.mq;

import com.doublez.pocketmind.framework.rabbitmq.core.RabbitMessageProducer;
import com.doublez.pocketmindserver.mq.ResourceOutboxMqConstants;
import com.doublez.pocketmindserver.resource.application.mq.ResourceOutboxHintEvent;
import com.doublez.pocketmindserver.resource.application.mq.ResourceOutboxHintPublisher;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Resource 索引 Outbox Hint 发布实现。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ResourceOutboxHintPublisherImpl implements ResourceOutboxHintPublisher {

    private final RabbitMessageProducer rabbitMessageProducer;

    @Override
    public void publish(ResourceOutboxHintEvent event) {
        rabbitMessageProducer.send(
                ResourceOutboxMqConstants.OUTBOX_HINT_EXCHANGE,
                ResourceOutboxMqConstants.OUTBOX_HINT_ROUTING_KEY,
                event
        );
        log.info(
                "[ResourceOutboxHintMQ] hint 已投递 - outboxEventUuid: {}, userId: {}, resourceUuid: {}, operation: {}",
                event.eventUuid(),
                event.userId(),
                event.resourceUuid(),
                event.operation()
        );
    }
}
