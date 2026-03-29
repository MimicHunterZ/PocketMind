package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxConstants;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Outbox 重试回归测试。
 */
class ResourceCatalogOutboxRetryTest {

    private final ResourceCatalogRuntimeProperties runtimeProperties =
            new ResourceCatalogRuntimeProperties(true, 100, 5000L, true);

    @Test
    void shouldRetryAfterFailureAndEventuallyComplete() {
        InMemoryOutboxRepository outbox = new InMemoryOutboxRepository();
        InMemoryResourceRecordRepository resources = new InMemoryResourceRecordRepository();
        FlakyCatalogSyncService catalog = new FlakyCatalogSyncService();
        ResourceCatalogProjector projector = new ResourceCatalogProjector(
                outbox,
                resources,
                catalog,
                runtimeProperties,
                new ResourceCatalogMetrics(new SimpleMeterRegistry(), runtimeProperties)
        );

        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(),
                9L,
                UUID.randomUUID(),
                ContextUri.userResourcesRoot(9L).child("notes").child("retry"),
                "标题",
                "内容"
        );
        resources.storage.add(resource);
        UUID eventUuid = UUID.randomUUID();
        outbox.appendPending(eventUuid, 9L, resource.getUuid(), ResourceIndexOutboxConstants.OPERATION_UPSERT);

        projector.projectOnce(10);
        assertEquals(1, outbox.failedCount);
        assertEquals(0, outbox.completedCount);

        // 强制允许下一次重试
        outbox.events.getFirst().setRetryAfter(0L);
        projector.projectOnce(10);

        assertEquals(1, outbox.failedCount);
        assertEquals(1, outbox.completedCount);
        assertTrue(catalog.syncCount >= 2);
    }

    @Test
    void shouldNotRequeueAfterCompletedWhenCompetingWorkerFailsLate() {
        InMemoryOutboxRepository outbox = new InMemoryOutboxRepository();
        UUID eventUuid = UUID.randomUUID();
        UUID resourceUuid = UUID.randomUUID();
        outbox.appendPending(eventUuid, 7L, resourceUuid, ResourceIndexOutboxConstants.OPERATION_UPSERT);

        ResourceIndexOutboxEntity claimed = outbox.claimRunnable(System.currentTimeMillis(), 10).getFirst();
        outbox.markCompleted(claimed.getUuid());
        outbox.markFailed(claimed.getUuid(), 123L, "late fail");

        assertEquals(ResourceIndexOutboxConstants.STATUS_COMPLETED, outbox.events.getFirst().getStatus());
        assertEquals(0, outbox.failedCount);
    }

    private static final class InMemoryOutboxRepository implements ResourceIndexOutboxRepository {
        private final List<ResourceIndexOutboxEntity> events = new ArrayList<>();
        private int failedCount = 0;
        private int completedCount = 0;

        @Override
        public void appendPending(UUID eventUuid, long userId, UUID resourceUuid, String operation) {
            events.add(ResourceIndexOutboxEntity.pending(eventUuid, userId, resourceUuid, operation));
        }

        @Override
        public List<ResourceIndexOutboxEntity> pollRunnable(long nowEpochMillis, int limit) {
            return events.stream()
                    .filter(e -> ResourceIndexOutboxConstants.STATUS_PENDING.equals(e.getStatus()))
                    .filter(e -> e.getRetryAfter() <= nowEpochMillis)
                    .limit(limit)
                    .toList();
        }

        @Override
        public List<ResourceIndexOutboxEntity> claimRunnable(long nowEpochMillis, int limit) {
            return pollRunnable(nowEpochMillis, limit).stream()
                    .peek(e -> e.setStatus(ResourceIndexOutboxConstants.STATUS_PROCESSING))
                    .toList();
        }

        @Override
        public int recoverStaleProcessing(long nowEpochMillis, long processingLeaseMillis) {
            long staleBefore = nowEpochMillis - Math.max(1L, processingLeaseMillis);
            int recovered = 0;
            for (ResourceIndexOutboxEntity event : events) {
                if (ResourceIndexOutboxConstants.STATUS_PROCESSING.equals(event.getStatus())
                        && event.getUpdatedAt() != null
                        && event.getUpdatedAt() <= staleBefore) {
                    event.setStatus(ResourceIndexOutboxConstants.STATUS_PENDING);
                    recovered++;
                }
            }
            return recovered;
        }

        @Override
        public void markCompleted(UUID eventUuid) {
            events.stream().filter(e -> e.getUuid().equals(eventUuid)).findFirst()
                    .filter(e -> ResourceIndexOutboxConstants.STATUS_PROCESSING.equals(e.getStatus()))
                    .ifPresent(e -> {
                        e.setStatus(ResourceIndexOutboxConstants.STATUS_COMPLETED);
                        completedCount++;
                    });
        }

        @Override
        public void markFailed(UUID eventUuid, long nextRetryAfterEpochMillis, String errorMessage) {
            events.stream().filter(e -> e.getUuid().equals(eventUuid)).findFirst().ifPresent(e -> {
                if (!ResourceIndexOutboxConstants.STATUS_PROCESSING.equals(e.getStatus())) {
                    return;
                }
                e.setStatus(ResourceIndexOutboxConstants.STATUS_PENDING);
                e.setRetryAfter(nextRetryAfterEpochMillis);
                e.setRetryCount(e.getRetryCount() + 1);
                failedCount++;
            });
        }
    }

    private static final class InMemoryResourceRecordRepository implements ResourceRecordRepository {
        private final List<ResourceRecordEntity> storage = new ArrayList<>();
        @Override public void save(ResourceRecordEntity resourceRecord) {}
        @Override public void update(ResourceRecordEntity resourceRecord) {}
        @Override public Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
            return storage.stream().filter(r -> r.getUuid().equals(uuid) && r.getUserId() == userId).findFirst();
        }
        @Override public Optional<ResourceRecordEntity> findByRootUriAndUserId(String rootUri, long userId) { return Optional.empty(); }
        @Override public List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid) { return List.of(); }
        @Override public List<ResourceRecordEntity> findBySessionUuid(long userId, UUID sessionUuid) { return List.of(); }
        @Override public List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid) { return List.of(); }
    }

    private static final class FlakyCatalogSyncService implements ResourceCatalogSyncService {
        private int syncCount = 0;

        @Override
        public void syncToCatalog(ResourceRecordEntity resource) {
            syncCount++;
            if (syncCount == 1) {
                throw new RuntimeException("first attempt fail");
            }
        }

        @Override
        public void removeFromCatalog(ResourceRecordEntity resource) {
        }

        @Override
        public void removeFromCatalogByResourceUuid(UUID resourceUuid) {
        }
    }
}
