package com.doublez.pocketmindserver.integration;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.resource.application.NoteResourceProjectionServiceImpl;
import com.doublez.pocketmindserver.resource.application.NoteResourceSyncServiceImpl;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogProjector;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogRuntimeProperties;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogSyncService;
import com.doublez.pocketmindserver.resource.application.ResourceContextServiceImpl;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogMetrics;
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
 * notes -> resource_records -> outbox -> projector 基线链路测试。
 */
class NoteResourceCatalogPipelineIT {

    private final ResourceCatalogRuntimeProperties runtimeProperties =
            new ResourceCatalogRuntimeProperties(true, 100, 5000L, true);

    @Test
    void shouldFlowFromNoteToResourceAndProjectCatalog() {
        InMemoryResourceRecordRepository resourceRepository = new InMemoryResourceRecordRepository();
        InMemoryOutboxRepository outboxRepository = new InMemoryOutboxRepository();
        RecordingCatalogSyncService catalogSyncService = new RecordingCatalogSyncService();

        NoteResourceSyncServiceImpl syncService = new NoteResourceSyncServiceImpl(
                new NoteResourceProjectionServiceImpl(new ResourceContextServiceImpl()),
                resourceRepository,
                outboxRepository,
                event -> {
                }
        );
        ResourceCatalogProjector projector = new ResourceCatalogProjector(
                outboxRepository,
                resourceRepository,
                catalogSyncService,
                runtimeProperties,
                new ResourceCatalogMetrics(new SimpleMeterRegistry(), runtimeProperties)
        );

        UUID noteUuid = UUID.randomUUID();
        NoteEntity note = NoteEntity.create(noteUuid, 11L);
        note.updateContent("标题", "正文");
        note.attachSourceUrl("url");

        syncService.syncProjectedResources(note);
        projector.projectOnce(10);

        assertEquals(1, resourceRepository.storage.size());
        assertEquals(1, outboxRepository.completed.size());
        assertEquals(1, catalogSyncService.synced.size());
        assertTrue(catalogSyncService.synced.getFirst().getRootUri().value().contains("notes"));
    }

    private static final class InMemoryResourceRecordRepository implements ResourceRecordRepository {
        private final List<ResourceRecordEntity> storage = new ArrayList<>();

        @Override public synchronized void save(ResourceRecordEntity resourceRecord) { storage.add(resourceRecord); }
        @Override public synchronized void update(ResourceRecordEntity resourceRecord) { }
        @Override public synchronized Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
            return storage.stream().filter(r -> r.getUuid().equals(uuid) && r.getUserId() == userId).findFirst();
        }
        @Override public Optional<ResourceRecordEntity> findByRootUriAndUserId(String rootUri, long userId) { return Optional.empty(); }
        @Override public List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid) {
            return storage.stream().filter(r -> noteUuid.equals(r.getNoteUuid()) && r.getUserId() == userId && !r.isDeleted()).toList();
        }
        @Override public List<ResourceRecordEntity> findBySessionUuid(long userId, UUID sessionUuid) { return List.of(); }
        @Override public List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid) { return List.of(); }
    }

    private static final class InMemoryOutboxRepository implements ResourceIndexOutboxRepository {
        private final List<ResourceIndexOutboxEntity> events = new ArrayList<>();
        private final List<UUID> completed = new ArrayList<>();

        @Override public synchronized void appendPending(UUID eventUuid, long userId, UUID resourceUuid, String operation) {
            events.add(ResourceIndexOutboxEntity.pending(eventUuid, userId, resourceUuid, operation));
        }

        @Override public synchronized List<ResourceIndexOutboxEntity> pollRunnable(long nowEpochMillis, int limit) {
            return events.stream()
                    .filter(e -> ResourceIndexOutboxConstants.STATUS_PENDING.equals(e.getStatus()))
                    .filter(e -> e.getRetryAfter() <= nowEpochMillis)
                    .limit(limit)
                    .toList();
        }

        @Override public synchronized List<ResourceIndexOutboxEntity> claimRunnable(long nowEpochMillis, int limit) {
            return pollRunnable(nowEpochMillis, limit).stream()
                    .peek(e -> e.setStatus(ResourceIndexOutboxConstants.STATUS_PROCESSING))
                    .toList();
        }

        @Override public synchronized void markCompleted(UUID eventUuid) {
            completed.add(eventUuid);
            events.stream().filter(e -> e.getUuid().equals(eventUuid)).findFirst()
                    .ifPresent(e -> e.setStatus(ResourceIndexOutboxConstants.STATUS_COMPLETED));
        }

        @Override public synchronized void markFailed(UUID eventUuid, long nextRetryAfterEpochMillis, String errorMessage) {
        }
    }

    private static final class RecordingCatalogSyncService implements ResourceCatalogSyncService {
        private final List<ResourceRecordEntity> synced = new ArrayList<>();
        @Override public void syncToCatalog(ResourceRecordEntity resource) { synced.add(resource); }
        @Override public void removeFromCatalog(ResourceRecordEntity resource) { }
        @Override public void removeFromCatalogByResourceUuid(UUID resourceUuid) { }
    }
}
