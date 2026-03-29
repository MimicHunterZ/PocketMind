package com.doublez.pocketmindserver.resource.application.mq;

import com.doublez.pocketmindserver.resource.application.ResourceCatalogProjector;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogRuntimeProperties;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * ResourceOutboxHintListener 测试。
 */
class ResourceOutboxHintListenerTest {

    @Test
    void shouldTriggerProjectorWhenHintReceived() {
        ResourceCatalogProjector projector = mock(ResourceCatalogProjector.class);
        ResourceCatalogRuntimeProperties properties = mock(ResourceCatalogRuntimeProperties.class);
        when(properties.getProjectorBatchSize()).thenReturn(100);

        ResourceOutboxHintListener listener = new ResourceOutboxHintListener(projector, properties);
        listener.onHint(new ResourceOutboxHintEvent(UUID.randomUUID(), 1L, UUID.randomUUID(), "UPSERT", System.currentTimeMillis()));

        verify(projector).projectOnce(100);
    }

    @Test
    void shouldRemainSafeWhenDuplicateHintReceived() {
        ResourceCatalogProjector projector = mock(ResourceCatalogProjector.class);
        ResourceCatalogRuntimeProperties properties = mock(ResourceCatalogRuntimeProperties.class);
        when(properties.getProjectorBatchSize()).thenReturn(100);

        ResourceOutboxHintListener listener = new ResourceOutboxHintListener(projector, properties);
        ResourceOutboxHintEvent sameEvent = new ResourceOutboxHintEvent(
                UUID.randomUUID(),
                1L,
                UUID.randomUUID(),
                "UPSERT",
                System.currentTimeMillis()
        );

        listener.onHint(sameEvent);
        listener.onHint(sameEvent);

        verify(projector, times(2)).projectOnce(100);
    }
}
