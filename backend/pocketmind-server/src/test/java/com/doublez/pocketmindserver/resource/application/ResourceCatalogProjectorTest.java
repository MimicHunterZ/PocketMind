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
 * ResourceCatalogProjector 测试。
 */
class ResourceCatalogProjectorTest {

    private final ResourceCatalogRuntimeProperties runtimeProperties =
            new ResourceCatalogRuntimeProperties(true, 100, 5000L, true);

    @Test
    void shouldProjectPendingUpsertEvent() {
        InMemoryOutboxRepository outbox = new InMemoryOutboxRepository();
        InMemoryResourceRecordRepository resources = new InMemoryResourceRecordRepository();
        RecordingCatalogSyncService catalog = new RecordingCatalogSyncService();
        ResourceCatalogProjector projector = newProjector(outbox, resources, catalog);

        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(),
                1L,
                UUID.randomUUID(),
                ContextUri.userResourcesRoot(1L).child("notes").child("p1"),
                "标题",
                "内容"
        );
        resources.storage.add(resource);
        outbox.events.add(ResourceIndexOutboxEntity.pending(
                UUID.randomUUID(),
                1L,
                resource.getUuid(),
                ResourceIndexOutboxConstants.OPERATION_UPSERT
        ));

        projector.projectOnce(10);

        assertEquals(1, catalog.upserted.size());
        assertEquals(1, outbox.completed.size());
    }

    @Test
    void shouldMarkFailedWhenSyncThrows() {
        InMemoryOutboxRepository outbox = new InMemoryOutboxRepository();
        InMemoryResourceRecordRepository resources = new InMemoryResourceRecordRepository();
        RecordingCatalogSyncService catalog = new RecordingCatalogSyncService();
        catalog.throwOnSync = true;
        ResourceCatalogProjector projector = newProjector(outbox, resources, catalog);

        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(),
                2L,
                UUID.randomUUID(),
                ContextUri.userResourcesRoot(2L).child("notes").child("p2"),
                "标题",
                "内容"
        );
        resources.storage.add(resource);
        ResourceIndexOutboxEntity event = ResourceIndexOutboxEntity.pending(
                UUID.randomUUID(),
                2L,
                resource.getUuid(),
                ResourceIndexOutboxConstants.OPERATION_UPSERT
        );
        outbox.events.add(event);

        projector.projectOnce(10);

        assertEquals(0, outbox.completed.size());
        assertEquals(1, outbox.failed.size());
        assertEquals(event.getUuid(), outbox.failed.getFirst().eventUuid);
    }

    @Test
    void shouldBeIdempotentAcrossMultiplePolls() {
        InMemoryOutboxRepository outbox = new InMemoryOutboxRepository();
        InMemoryResourceRecordRepository resources = new InMemoryResourceRecordRepository();
        RecordingCatalogSyncService catalog = new RecordingCatalogSyncService();
        ResourceCatalogProjector projector = newProjector(outbox, resources, catalog);

        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(),
                3L,
                UUID.randomUUID(),
                ContextUri.userResourcesRoot(3L).child("notes").child("p3"),
                "标题",
                "内容"
        );
        resources.storage.add(resource);
        outbox.events.add(ResourceIndexOutboxEntity.pending(
                UUID.randomUUID(),
                3L,
                resource.getUuid(),
                ResourceIndexOutboxConstants.OPERATION_UPSERT
        ));

        projector.projectOnce(10);
        projector.projectOnce(10);

        assertEquals(1, catalog.upserted.size());
        assertEquals(1, outbox.completed.size());
    }

    @Test
    void shouldDeleteCatalogByResourceUuidWhenDeleteEventAndResourceSoftDeleted() {
        InMemoryOutboxRepository outbox = new InMemoryOutboxRepository();
        InMemoryResourceRecordRepository resources = new InMemoryResourceRecordRepository();
        RecordingCatalogSyncService catalog = new RecordingCatalogSyncService();
        ResourceCatalogProjector projector = newProjector(outbox, resources, catalog);

        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(),
                8L,
                UUID.randomUUID(),
                ContextUri.userResourcesRoot(8L).child("notes").child("to-delete"),
                "标题",
                "内容"
        );
        resource.softDelete();
        resources.storage.add(resource);
        outbox.events.add(ResourceIndexOutboxEntity.pending(
                UUID.randomUUID(),
                8L,
                resource.getUuid(),
                ResourceIndexOutboxConstants.OPERATION_DELETE
        ));

        projector.projectOnce(10);

        assertEquals(1, outbox.completed.size());
        assertEquals(1, catalog.deletedByResourceUuid.size());
        assertEquals(resource.getUuid(), catalog.deletedByResourceUuid.getFirst());
    }

    @Test
    void shouldDeleteCatalogByResourceUuidWhenDeleteEventButResourceMissing() {
        InMemoryOutboxRepository outbox = new InMemoryOutboxRepository();
        InMemoryResourceRecordRepository resources = new InMemoryResourceRecordRepository();
        RecordingCatalogSyncService catalog = new RecordingCatalogSyncService();
        ResourceCatalogProjector projector = newProjector(outbox, resources, catalog);

        UUID missingResourceUuid = UUID.randomUUID();
        outbox.events.add(ResourceIndexOutboxEntity.pending(
                UUID.randomUUID(),
                10L,
                missingResourceUuid,
                ResourceIndexOutboxConstants.OPERATION_DELETE
        ));

        projector.projectOnce(10);

        assertEquals(1, outbox.completed.size());
        assertEquals(List.of(missingResourceUuid), catalog.deletedByResourceUuid);
    }

    @Test
    void shouldRecoverStaleProcessingEventBeforeClaim() {
        InMemoryOutboxRepository outbox = new InMemoryOutboxRepository();
        InMemoryResourceRecordRepository resources = new InMemoryResourceRecordRepository();
        RecordingCatalogSyncService catalog = new RecordingCatalogSyncService();
        ResourceCatalogProjector projector = newProjector(outbox, resources, catalog);

        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(),
                11L,
                UUID.randomUUID(),
                ContextUri.userResourcesRoot(11L).child("notes").child("stale-processing"),
                "标题",
                "内容"
        );
        resources.storage.add(resource);

        ResourceIndexOutboxEntity processing = ResourceIndexOutboxEntity.pending(
                UUID.randomUUID(),
                11L,
                resource.getUuid(),
                ResourceIndexOutboxConstants.OPERATION_UPSERT
        );
        processing.setStatus(ResourceIndexOutboxConstants.STATUS_PROCESSING);
        processing.setUpdatedAt(0L);
        outbox.events.add(processing);

        projector.projectOnce(10);

        assertEquals(1, catalog.upserted.size());
        assertEquals(1, outbox.completed.size());
    }

    private static final class InMemoryOutboxRepository implements ResourceIndexOutboxRepository {
        private final List<ResourceIndexOutboxEntity> events = new ArrayList<>();
        private final List<UUID> completed = new ArrayList<>();
        private final List<FailedMark> failed = new ArrayList<>();

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
            completed.add(eventUuid);
            events.stream().filter(e -> e.getUuid().equals(eventUuid)).findFirst()
                    .ifPresent(e -> e.setStatus(ResourceIndexOutboxConstants.STATUS_COMPLETED));
        }

        @Override
        public void markFailed(UUID eventUuid, long nextRetryAfterEpochMillis, String errorMessage) {
            failed.add(new FailedMark(eventUuid, nextRetryAfterEpochMillis, errorMessage));
            events.stream().filter(e -> e.getUuid().equals(eventUuid)).findFirst().ifPresent(e -> {
                e.setStatus(ResourceIndexOutboxConstants.STATUS_PENDING);
                e.setRetryAfter(nextRetryAfterEpochMillis);
                e.setLastError(errorMessage);
                e.setRetryCount(e.getRetryCount() + 1);
            });
        }
    }

    private static final class InMemoryResourceRecordRepository implements ResourceRecordRepository {
        private final List<ResourceRecordEntity> storage = new ArrayList<>();

        @Override
        public void save(ResourceRecordEntity resourceRecord) {
            storage.add(resourceRecord);
        }

        @Override
        public void update(ResourceRecordEntity resourceRecord) {
        }

        @Override
        public Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
            return storage.stream()
                    .filter(r -> !r.isDeleted())
                    .filter(r -> r.getUuid().equals(uuid) && r.getUserId() == userId)
                    .findFirst();
        }

        @Override
        public Optional<ResourceRecordEntity> findByUuidAndUserIdIncludingDeleted(UUID uuid, long userId) {
            return storage.stream()
                    .filter(r -> r.getUuid().equals(uuid) && r.getUserId() == userId)
                    .findFirst();
        }

        @Override
        public Optional<ResourceRecordEntity> findByRootUriAndUserId(String rootUri, long userId) {
            return Optional.empty();
        }

        @Override
        public List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid) {
            return List.of();
        }

        @Override
        public List<ResourceRecordEntity> findBySessionUuid(long userId, UUID sessionUuid) {
            return List.of();
        }

        @Override
        public List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid) {
            return List.of();
        }
    }

    private static final class RecordingCatalogSyncService implements ResourceCatalogSyncService {
        private final List<ResourceRecordEntity> upserted = new ArrayList<>();
        private final List<UUID> deletedByResourceUuid = new ArrayList<>();
        private boolean throwOnSync = false;

        @Override
        public void syncToCatalog(ResourceRecordEntity resource) {
            if (throwOnSync) {
                throw new RuntimeException("sync failed");
            }
            upserted.add(resource);
        }

        @Override
        public void removeFromCatalog(ResourceRecordEntity resource) {
            deletedByResourceUuid.add(resource.getUuid());
        }

        @Override
        public void removeFromCatalogByResourceUuid(UUID resourceUuid) {
            deletedByResourceUuid.add(resourceUuid);
        }
    }

    private record FailedMark(UUID eventUuid, long retryAfter, String error) {
    }

    private ResourceCatalogProjector newProjector(InMemoryOutboxRepository outbox,
                                                  InMemoryResourceRecordRepository resources,
                                                  RecordingCatalogSyncService catalog) {
        return new ResourceCatalogProjector(
                outbox,
                resources,
                catalog,
                runtimeProperties,
                new ResourceCatalogMetrics(new SimpleMeterRegistry(), runtimeProperties)
        );
    }
}
