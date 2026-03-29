package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxConstants;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * Catalog 异步投影器。
 */
@Slf4j
@Service
public class ResourceCatalogProjector {

    private final ResourceIndexOutboxRepository outboxRepository;
    private final ResourceRecordRepository resourceRecordRepository;
    private final ResourceCatalogSyncService resourceCatalogSyncService;
    private final ResourceCatalogRuntimeProperties runtimeProperties;
    private final ResourceCatalogMetrics resourceCatalogMetrics;

    public ResourceCatalogProjector(ResourceIndexOutboxRepository outboxRepository,
                                    ResourceRecordRepository resourceRecordRepository,
                                    ResourceCatalogSyncService resourceCatalogSyncService,
                                    ResourceCatalogRuntimeProperties runtimeProperties,
                                    ResourceCatalogMetrics resourceCatalogMetrics) {
        this.outboxRepository = outboxRepository;
        this.resourceRecordRepository = resourceRecordRepository;
        this.resourceCatalogSyncService = resourceCatalogSyncService;
        this.runtimeProperties = runtimeProperties;
        this.resourceCatalogMetrics = resourceCatalogMetrics;
    }

    /**
     * 执行一次 outbox 投影。
     */
    public void projectOnce(int limit) {
        long startedAt = System.nanoTime();
        long now = System.currentTimeMillis();
        int effectiveLimit = resolveLimit(limit);
        int recovered = outboxRepository.recoverStaleProcessing(now, runtimeProperties.getOutboxProcessingLeaseMillis());
        if (recovered > 0) {
            log.warn("[resource-catalog-projector] 回收超时 PROCESSING 事件: count={}", recovered);
        }
        List<ResourceIndexOutboxEntity> events = outboxRepository.claimRunnable(now, effectiveLimit);
        resourceCatalogMetrics.updateOutboxBacklog(events.size());
        int failedCount = 0;
        for (ResourceIndexOutboxEntity event : events) {
            try {
                processEvent(event);
                outboxRepository.markCompleted(event.getUuid());
            } catch (Exception e) {
                failedCount++;
                long retryAfter = System.currentTimeMillis() + runtimeProperties.getProjectorRetryIntervalMillis();
                outboxRepository.markFailed(event.getUuid(), retryAfter, safeErrorMessage(e));
                log.warn("[resource-catalog-projector] 投影失败, 已标记重试: eventUuid={}, error={}",
                        event.getUuid(), e.getMessage());
            }
        }
        resourceCatalogMetrics.updateFailedCount(failedCount);
        resourceCatalogMetrics.recordProjectorLatencyNanos(System.nanoTime() - startedAt);
    }

    private int resolveLimit(int limit) {
        if (limit > 0) {
            return limit;
        }
        return runtimeProperties.getProjectorBatchSize();
    }

    private void processEvent(ResourceIndexOutboxEntity event) {
        if (ResourceIndexOutboxConstants.OPERATION_UPSERT.equals(event.getOperation())) {
            Optional<ResourceRecordEntity> resource = resourceRecordRepository.findByUuidAndUserId(
                    event.getResourceUuid(),
                    event.getUserId()
            );
            if (resource.isPresent() && !resource.get().isDeleted()) {
                resourceCatalogSyncService.syncToCatalog(resource.get());
            }
            return;
        }

        if (ResourceIndexOutboxConstants.OPERATION_DELETE.equals(event.getOperation())) {
            Optional<ResourceRecordEntity> resourceIncludingDeleted = resourceRecordRepository.findByUuidAndUserIdIncludingDeleted(
                    event.getResourceUuid(),
                    event.getUserId()
            );
            if (resourceIncludingDeleted.isPresent()) {
                resourceCatalogSyncService.removeFromCatalog(resourceIncludingDeleted.get());
            } else {
                resourceCatalogSyncService.removeFromCatalogByResourceUuid(event.getResourceUuid());
            }
            return;
        }

        log.warn("[resource-catalog-projector] 未知 outbox 操作类型: eventUuid={}, operation={}",
                event.getUuid(), event.getOperation());
    }

    private String safeErrorMessage(Exception e) {
        String message = e.getMessage();
        if (message == null || message.isBlank()) {
            return e.getClass().getSimpleName();
        }
        return message.length() > 500 ? message.substring(0, 500) : message;
    }
}
