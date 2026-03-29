package com.doublez.pocketmindserver.resource.application;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * ResourceCatalogRuntimeProperties 测试。
 */
class ResourceCatalogRuntimePropertiesTest {

    @Test
    void shouldUseDefaultValuesWhenConstructedWithoutArgs() {
        ResourceCatalogRuntimeProperties properties = new ResourceCatalogRuntimeProperties();

        assertTrue(properties.isRetrievalFallbackEnabled());
        assertEquals(100, properties.getProjectorBatchSize());
        assertEquals(5000L, properties.getProjectorRetryIntervalMillis());
        assertEquals(2, properties.getHintListenerConcurrency());
        assertEquals(300L, properties.getHintDebounceMillis());
        assertEquals(3, properties.getHintMaxRetry());
        assertEquals(3, properties.getHintDlqMaxReplay());
        assertEquals(60000L, properties.getOutboxProcessingLeaseMillis());
        assertTrue(properties.isMetricsEnabled());
    }

    @Test
    void shouldNormalizeInvalidNumericValues() {
        ResourceCatalogRuntimeProperties properties = new ResourceCatalogRuntimeProperties(false, -1, -1L, false);

        assertFalse(properties.isRetrievalFallbackEnabled());
        assertEquals(100, properties.getProjectorBatchSize());
        assertEquals(5000L, properties.getProjectorRetryIntervalMillis());
        properties.setHintListenerConcurrency(0);
        properties.setHintDebounceMillis(-1L);
        properties.setHintMaxRetry(0);
        properties.setHintDlqMaxReplay(0);
        properties.setOutboxProcessingLeaseMillis(0L);
        assertEquals(2, properties.getHintListenerConcurrency());
        assertEquals(300L, properties.getHintDebounceMillis());
        assertEquals(3, properties.getHintMaxRetry());
        assertEquals(3, properties.getHintDlqMaxReplay());
        assertEquals(60000L, properties.getOutboxProcessingLeaseMillis());
        assertFalse(properties.isMetricsEnabled());
    }
}
