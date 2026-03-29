package com.doublez.pocketmindserver.resource.application.mq;

import com.doublez.pocketmindserver.resource.application.ResourceCatalogMetrics;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

/**
 * ResourceOutboxHintAfterCommitListener 测试。
 */
class ResourceOutboxHintAfterCommitListenerTest {

    @Test
    void shouldPublishHintOnAfterCommit() {
        ResourceOutboxHintPublisher publisher = mock(ResourceOutboxHintPublisher.class);
        ResourceOutboxHintCompensationPublisher compensationPublisher = mock(ResourceOutboxHintCompensationPublisher.class);
        ResourceCatalogMetrics metrics = mock(ResourceCatalogMetrics.class);
        ResourceOutboxHintAfterCommitListener listener = new ResourceOutboxHintAfterCommitListener(publisher, compensationPublisher, metrics);

        ResourceOutboxHintEvent event = new ResourceOutboxHintEvent(UUID.randomUUID(), 1L, UUID.randomUUID(), "UPSERT", System.currentTimeMillis());
        listener.onAfterCommit(event);

        verify(publisher).publish(event);
    }

    @Test
    void shouldFallbackToCompensationWhenPublishFails() {
        ResourceOutboxHintPublisher publisher = mock(ResourceOutboxHintPublisher.class);
        ResourceOutboxHintCompensationPublisher compensationPublisher = mock(ResourceOutboxHintCompensationPublisher.class);
        ResourceCatalogMetrics metrics = mock(ResourceCatalogMetrics.class);
        ResourceOutboxHintAfterCommitListener listener = new ResourceOutboxHintAfterCommitListener(publisher, compensationPublisher, metrics);
        ResourceOutboxHintEvent event = new ResourceOutboxHintEvent(UUID.randomUUID(), 2L, UUID.randomUUID(), "UPSERT", System.currentTimeMillis());

        doThrow(new RuntimeException("publish failed")).when(publisher).publish(event);
        listener.onAfterCommit(event);

        verify(compensationPublisher).publishCompensation(event, "publish failed");
    }

    @Test
    void shouldOnlyRecordMetricWhenCompensationPublishAlsoFails() {
        ResourceOutboxHintPublisher publisher = mock(ResourceOutboxHintPublisher.class);
        ResourceOutboxHintCompensationPublisher compensationPublisher = mock(ResourceOutboxHintCompensationPublisher.class);
        ResourceCatalogMetrics metrics = mock(ResourceCatalogMetrics.class);
        ResourceOutboxHintAfterCommitListener listener = new ResourceOutboxHintAfterCommitListener(publisher, compensationPublisher, metrics);
        ResourceOutboxHintEvent event = new ResourceOutboxHintEvent(UUID.randomUUID(), 3L, UUID.randomUUID(), "UPSERT", System.currentTimeMillis());

        doThrow(new RuntimeException("publish failed")).when(publisher).publish(event);
        doThrow(new RuntimeException("compensation failed")).when(compensationPublisher)
                .publishCompensation(event, "publish failed");

        listener.onAfterCommit(event);

        verify(metrics).incrementHintPublishFail();
        verify(publisher).publish(event);
        verify(compensationPublisher).publishCompensation(event, "publish failed");
        verify(metrics, never()).incrementDlqReplayFail();
    }
}
