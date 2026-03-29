package com.doublez.pocketmindserver.resource.application;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.stereotype.Component;

import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Resource Catalog 投影链路指标。
 */
@Component
public class ResourceCatalogMetrics {

    private final ResourceCatalogRuntimeProperties runtimeProperties;
    private final Timer projectorLatencyTimer;
    private final AtomicInteger lastOutboxBacklog = new AtomicInteger(0);
    private final AtomicInteger lastFailedCount = new AtomicInteger(0);
    private final AtomicInteger hintPublishFailCount = new AtomicInteger(0);
    private final AtomicInteger dlqReplaySuccessCount = new AtomicInteger(0);
    private final AtomicInteger dlqReplayFailCount = new AtomicInteger(0);

    public ResourceCatalogMetrics(MeterRegistry meterRegistry,
                                  ResourceCatalogRuntimeProperties runtimeProperties) {
        this.runtimeProperties = runtimeProperties;
        this.projectorLatencyTimer = Timer.builder("pocketmind.resource.catalog.projector.latency")
                .description("Catalog projector 单轮处理耗时")
                .register(meterRegistry);
        Gauge.builder("pocketmind.resource.catalog.outbox.backlog", lastOutboxBacklog, AtomicInteger::get)
                .description("Outbox 待处理积压数量")
                .register(meterRegistry);
        Gauge.builder("pocketmind.resource.catalog.projector.failed", lastFailedCount, AtomicInteger::get)
                .description("Projector 单轮失败事件数量")
                .register(meterRegistry);
        Gauge.builder("pocketmind.resource.catalog.hint.publish.fail", hintPublishFailCount, AtomicInteger::get)
                .description("Hint 发布失败累计次数")
                .register(meterRegistry);
        Gauge.builder("pocketmind.resource.catalog.hint.dlq.replay.success", dlqReplaySuccessCount, AtomicInteger::get)
                .description("DLQ 重放成功累计次数")
                .register(meterRegistry);
        Gauge.builder("pocketmind.resource.catalog.hint.dlq.replay.fail", dlqReplayFailCount, AtomicInteger::get)
                .description("DLQ 重放失败累计次数")
                .register(meterRegistry);
    }

    public void recordProjectorLatencyNanos(long nanos) {
        if (!runtimeProperties.isMetricsEnabled()) {
            return;
        }
        projectorLatencyTimer.record(nanos, TimeUnit.NANOSECONDS);
    }

    public void updateOutboxBacklog(int backlog) {
        if (!runtimeProperties.isMetricsEnabled()) {
            return;
        }
        lastOutboxBacklog.set(Math.max(backlog, 0));
    }

    public void updateFailedCount(int failedCount) {
        if (!runtimeProperties.isMetricsEnabled()) {
            return;
        }
        lastFailedCount.set(Math.max(failedCount, 0));
    }

    public void incrementHintPublishFail() {
        if (!runtimeProperties.isMetricsEnabled()) {
            return;
        }
        hintPublishFailCount.incrementAndGet();
    }

    public void incrementDlqReplaySuccess() {
        if (!runtimeProperties.isMetricsEnabled()) {
            return;
        }
        dlqReplaySuccessCount.incrementAndGet();
    }

    public void incrementDlqReplayFail() {
        if (!runtimeProperties.isMetricsEnabled()) {
            return;
        }
        dlqReplayFailCount.incrementAndGet();
    }
}
