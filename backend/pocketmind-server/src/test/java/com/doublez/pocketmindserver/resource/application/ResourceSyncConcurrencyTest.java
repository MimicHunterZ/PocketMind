package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Resource 同步并发测试。
 */
class ResourceSyncConcurrencyTest {

    @Test
    void shouldRemainConsistentWhenConcurrentUpdates() throws Exception {
        InMemoryResourceRecordRepository resources = new InMemoryResourceRecordRepository();
        InMemoryOutboxRepository outbox = new InMemoryOutboxRepository();
        NoteResourceSyncServiceImpl service = new NoteResourceSyncServiceImpl(
                new NoteResourceProjectionServiceImpl(new ResourceContextServiceImpl()),
                resources,
                outbox,
                event -> {
                }
        );

        UUID noteUuid = UUID.randomUUID();
        int workers = 8;
        CountDownLatch latch = new CountDownLatch(workers);
        var pool = Executors.newFixedThreadPool(workers);

        for (int i = 0; i < workers; i++) {
            final int idx = i;
            pool.submit(() -> {
                try {
                    NoteEntity note = NoteEntity.create(noteUuid, 77L);
                    note.updateContent("标题" + idx, "正文" + idx);
                    note.attachSourceUrl("url");
                    service.syncProjectedResources(note);
                } finally {
                    latch.countDown();
                }
            });
        }

        assertTrue(latch.await(5, TimeUnit.SECONDS));
        pool.shutdown();

        List<ResourceRecordEntity> noteResources = resources.findByNoteUuid(77L, noteUuid);
        assertTrue(noteResources.size() >= 1);
        assertTrue(noteResources.getFirst().getSourceType() == com.doublez.pocketmindserver.resource.domain.ResourceSourceType.WEB_CLIP);
        assertTrue(noteResources.getFirst().getTitle() == null || noteResources.getFirst().getTitle().startsWith("标题"));
        assertEquals(workers, outbox.events.size());
    }

    private static final class InMemoryResourceRecordRepository implements ResourceRecordRepository {
        private final List<ResourceRecordEntity> storage = new ArrayList<>();

        @Override public synchronized void save(ResourceRecordEntity resourceRecord) { storage.add(resourceRecord); }
        @Override public synchronized void update(ResourceRecordEntity resourceRecord) {
            for (int i = 0; i < storage.size(); i++) {
                if (storage.get(i).getUuid().equals(resourceRecord.getUuid())) {
                    storage.set(i, resourceRecord);
                    return;
                }
            }
            storage.add(resourceRecord);
        }
        @Override public synchronized Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId) { return Optional.empty(); }
        @Override public synchronized Optional<ResourceRecordEntity> findByRootUriAndUserId(String rootUri, long userId) {
            return storage.stream().filter(r -> rootUri.equals(r.getRootUri().value()) && r.getUserId() == userId && !r.isDeleted()).findFirst();
        }
        @Override public synchronized List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid) {
            return storage.stream().filter(r -> noteUuid.equals(r.getNoteUuid()) && r.getUserId() == userId && !r.isDeleted()).toList();
        }
        @Override public synchronized List<ResourceRecordEntity> findBySessionUuid(long userId, UUID sessionUuid) { return List.of(); }
        @Override public synchronized List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid) { return List.of(); }
    }

    private static final class InMemoryOutboxRepository implements ResourceIndexOutboxRepository {
        private final List<ResourceIndexOutboxEntity> events = new ArrayList<>();
        @Override public synchronized void appendPending(UUID eventUuid, long userId, UUID resourceUuid, String operation) {
            events.add(ResourceIndexOutboxEntity.pending(eventUuid, userId, resourceUuid, operation));
        }
        @Override public synchronized List<ResourceIndexOutboxEntity> pollRunnable(long nowEpochMillis, int limit) { return List.of(); }
        @Override public synchronized List<ResourceIndexOutboxEntity> claimRunnable(long nowEpochMillis, int limit) { return List.of(); }
        @Override public synchronized void markCompleted(UUID eventUuid) {}
        @Override public synchronized void markFailed(UUID eventUuid, long nextRetryAfterEpochMillis, String errorMessage) {}
    }
}
