package com.doublez.pocketmindserver.resource.application;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

/**
 * ResourceCatalogMetrics 测试。
 */
class ResourceCatalogMetricsTest {

    @Test
    void shouldRecordMetricsWhenEnabled() {
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        ResourceCatalogRuntimeProperties properties = new ResourceCatalogRuntimeProperties(true, 100, 5000L, true);
        ResourceCatalogMetrics metrics = new ResourceCatalogMetrics(registry, properties);

        metrics.updateOutboxBacklog(7);
        metrics.updateFailedCount(2);
        metrics.recordProjectorLatencyNanos(2_000_000L);

        Gauge backlogGauge = registry.find("pocketmind.resource.catalog.outbox.backlog").gauge();
        Gauge failedGauge = registry.find("pocketmind.resource.catalog.projector.failed").gauge();
        Timer latencyTimer = registry.find("pocketmind.resource.catalog.projector.latency").timer();

        assertNotNull(backlogGauge);
        assertNotNull(failedGauge);
        assertNotNull(latencyTimer);
        assertEquals(7.0, backlogGauge.value());
        assertEquals(2.0, failedGauge.value());
        assertEquals(1L, latencyTimer.count());
    }

    @Test
    void shouldSkipMetricsRecordingWhenDisabled() {
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        ResourceCatalogRuntimeProperties properties = new ResourceCatalogRuntimeProperties(true, 100, 5000L, false);
        ResourceCatalogMetrics metrics = new ResourceCatalogMetrics(registry, properties);

        metrics.updateOutboxBacklog(9);
        metrics.updateFailedCount(3);
        metrics.recordProjectorLatencyNanos(1_000_000L);

        Gauge backlogGauge = registry.find("pocketmind.resource.catalog.outbox.backlog").gauge();
        Gauge failedGauge = registry.find("pocketmind.resource.catalog.projector.failed").gauge();
        Timer latencyTimer = registry.find("pocketmind.resource.catalog.projector.latency").timer();

        assertNotNull(backlogGauge);
        assertNotNull(failedGauge);
        assertNotNull(latencyTimer);
        assertEquals(0.0, backlogGauge.value());
        assertEquals(0.0, failedGauge.value());
        assertEquals(0L, latencyTimer.count());
    }
}
