package com.doublez.pocketmindserver.resource.infra.mq;

import com.doublez.pocketmind.framework.rabbitmq.core.RabbitMessageProducer;
import com.doublez.pocketmindserver.mq.ResourceOutboxMqConstants;
import com.doublez.pocketmindserver.resource.application.mq.ResourceOutboxHintCompensationPublisher;
import com.doublez.pocketmindserver.resource.application.mq.ResourceOutboxHintEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Resource Outbox Hint 补偿发布实现。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ResourceOutboxHintCompensationPublisherImpl implements ResourceOutboxHintCompensationPublisher {

    private final RabbitMessageProducer rabbitMessageProducer;

    @Override
    public void publishCompensation(ResourceOutboxHintEvent event, String reason) {
        rabbitMessageProducer.send(
                ResourceOutboxMqConstants.OUTBOX_HINT_EXCHANGE,
                ResourceOutboxMqConstants.OUTBOX_HINT_ROUTING_KEY,
                event
        );
        log.warn("[ResourceOutboxHintCompensation] 触发补偿重发: eventUuid={}, reason={}", event.eventUuid(), reason);
    }
}
