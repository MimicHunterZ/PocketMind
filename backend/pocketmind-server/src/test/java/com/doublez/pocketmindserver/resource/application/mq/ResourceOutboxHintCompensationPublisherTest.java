package com.doublez.pocketmindserver.resource.application.mq;

import com.doublez.pocketmind.framework.rabbitmq.core.RabbitMessageProducer;
import com.doublez.pocketmindserver.mq.ResourceOutboxMqConstants;
import com.doublez.pocketmindserver.resource.infra.mq.ResourceOutboxHintCompensationPublisherImpl;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

/**
 * ResourceOutboxHintCompensationPublisher 测试。
 */
class ResourceOutboxHintCompensationPublisherTest {

    @Test
    void shouldPublishCompensationMessage() {
        RabbitMessageProducer producer = mock(RabbitMessageProducer.class);
        ResourceOutboxHintCompensationPublisherImpl publisher = new ResourceOutboxHintCompensationPublisherImpl(producer);

        ResourceOutboxHintEvent event = new ResourceOutboxHintEvent(
                UUID.randomUUID(),
                7L,
                UUID.randomUUID(),
                "UPSERT",
                System.currentTimeMillis()
        );
        publisher.publishCompensation(event, "mock-reason");

        verify(producer).send(
                ResourceOutboxMqConstants.OUTBOX_HINT_EXCHANGE,
                ResourceOutboxMqConstants.OUTBOX_HINT_ROUTING_KEY,
                event
        );
    }
}
