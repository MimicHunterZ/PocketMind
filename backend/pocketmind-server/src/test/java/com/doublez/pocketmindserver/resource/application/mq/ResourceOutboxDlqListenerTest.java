package com.doublez.pocketmindserver.resource.application.mq;

import com.doublez.pocketmindserver.resource.application.ResourceCatalogMetrics;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogProjector;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogRuntimeProperties;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * ResourceOutboxDlqListener 测试。
 */
class ResourceOutboxDlqListenerTest {

    @Test
    void shouldTriggerProjectorWhenDlqMessageReceived() {
        ResourceCatalogProjector projector = mock(ResourceCatalogProjector.class);
        ResourceCatalogRuntimeProperties properties = mock(ResourceCatalogRuntimeProperties.class);
        ResourceCatalogMetrics metrics = mock(ResourceCatalogMetrics.class);
        when(properties.getProjectorBatchSize()).thenReturn(64);
        when(properties.getHintDlqMaxReplay()).thenReturn(3);

        ResourceOutboxDlqListener listener = new ResourceOutboxDlqListener(projector, properties, metrics);
        listener.onDlq(new ResourceOutboxHintEvent(UUID.randomUUID(), 2L, UUID.randomUUID(), "UPSERT", System.currentTimeMillis()));

        verify(projector).projectOnce(64);
    }

    @Test
    void shouldStopReplayWhenExceededMaxReplay() {
        ResourceCatalogProjector projector = mock(ResourceCatalogProjector.class);
        ResourceCatalogRuntimeProperties properties = mock(ResourceCatalogRuntimeProperties.class);
        ResourceCatalogMetrics metrics = mock(ResourceCatalogMetrics.class);
        when(properties.getProjectorBatchSize()).thenReturn(64);
        when(properties.getHintDlqMaxReplay()).thenReturn(1);

        ResourceOutboxDlqListener listener = new ResourceOutboxDlqListener(projector, properties, metrics);
        ResourceOutboxHintEvent event = new ResourceOutboxHintEvent(UUID.randomUUID(), 2L, UUID.randomUUID(), "UPSERT", System.currentTimeMillis());

        listener.onDlq(event);
        listener.onDlq(event);

        verify(projector).projectOnce(64);
    }

    @Test
    void shouldClearReplayCounterWhenReplaySucceeded() {
        ResourceCatalogProjector projector = mock(ResourceCatalogProjector.class);
        ResourceCatalogRuntimeProperties properties = mock(ResourceCatalogRuntimeProperties.class);
        ResourceCatalogMetrics metrics = mock(ResourceCatalogMetrics.class);
        when(properties.getProjectorBatchSize()).thenReturn(64);
        when(properties.getHintDlqMaxReplay()).thenReturn(2);

        ResourceOutboxDlqListener listener = new ResourceOutboxDlqListener(projector, properties, metrics);
        ResourceOutboxHintEvent event = new ResourceOutboxHintEvent(UUID.randomUUID(), 2L, UUID.randomUUID(), "UPSERT", System.currentTimeMillis());

        listener.onDlq(event);
        listener.onDlq(event);

        verify(projector, times(2)).projectOnce(64);
        verify(metrics, never()).incrementDlqReplayFail();
    }

    @Test
    void shouldClearReplayCounterWhenExceededMaxReplay() {
        ResourceCatalogProjector projector = mock(ResourceCatalogProjector.class);
        ResourceCatalogRuntimeProperties properties = mock(ResourceCatalogRuntimeProperties.class);
        ResourceCatalogMetrics metrics = mock(ResourceCatalogMetrics.class);
        when(properties.getProjectorBatchSize()).thenReturn(64);
        when(properties.getHintDlqMaxReplay()).thenReturn(1);

        ResourceOutboxDlqListener listener = new ResourceOutboxDlqListener(projector, properties, metrics);
        ResourceOutboxHintEvent event = new ResourceOutboxHintEvent(UUID.randomUUID(), 2L, UUID.randomUUID(), "UPSERT", System.currentTimeMillis());

        listener.onDlq(event);
        listener.onDlq(event);

        verify(projector).projectOnce(64);
        verify(metrics).incrementDlqReplayFail();
    }
}
