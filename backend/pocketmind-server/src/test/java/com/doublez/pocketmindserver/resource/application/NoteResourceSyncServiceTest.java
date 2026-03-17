package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import com.doublez.pocketmindserver.resource.application.NoOpResourceCatalogSyncService;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * NoteResourceSyncService 同步测试。
 */
class NoteResourceSyncServiceTest {

    private final InMemoryResourceRecordRepository repository = new InMemoryResourceRecordRepository();
    private final NoteResourceSyncService service = new NoteResourceSyncServiceImpl(
            new NoteResourceProjectionServiceImpl(new ResourceContextServiceImpl()),
            repository,
            new NoOpResourceCatalogSyncService()
    );

    @Test
    void shouldCreateNoteTextAndWebClipResources() {
        NoteEntity note = new NoteEntity(
                UUID.randomUUID(),
                7L,
                "正文标题",
                "正文内容",
                "https://example.com/share/1",
                1L,
                Collections.emptyList(),
                null,
                "抓取标题",
                "抓取描述",
                "抓取正文",
                null,
                null,
                null,
                System.currentTimeMillis(),
                false,
                null
        );

        service.syncProjectedResources(note);

        List<ResourceRecordEntity> resources = repository.findByNoteUuid(note.getUserId(), note.getUuid());
        assertEquals(2, resources.size());
        assertTrue(resources.stream().anyMatch(resource -> resource.getSourceType() == ResourceSourceType.NOTE_TEXT));
        assertTrue(resources.stream().anyMatch(resource -> resource.getSourceType() == ResourceSourceType.WEB_CLIP));
    }

    @Test
    void shouldSoftDeleteNoteTextResourceWhenContentCleared() {
        NoteEntity note = new NoteEntity(
                UUID.randomUUID(),
                8L,
                "标题",
                "旧正文",
                null,
                1L,
                Collections.emptyList(),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                System.currentTimeMillis(),
                false,
                null
        );

        service.syncProjectedResources(note);
        note.updateContent("标题", "   ");
        service.syncProjectedResources(note);

        assertEquals(0, repository.findByNoteUuid(note.getUserId(), note.getUuid()).size());
        assertEquals(1, repository.storage.size());
        assertTrue(repository.storage.getFirst().isDeleted());
    }

    @Test
    void shouldRefreshWebClipSourceUrlOnUpdate() {
        NoteEntity note = new NoteEntity(
                UUID.randomUUID(),
                9L,
                null,
                null,
                "https://example.com/old",
                1L,
                Collections.emptyList(),
                null,
                "旧标题",
                null,
                "旧正文",
                null,
                null,
                null,
                System.currentTimeMillis(),
                false,
                null
        );
        service.syncProjectedResources(note);

        note.attachSourceUrl("https://example.com/new");
        note.completeFetch("新标题", "新描述", "新正文");
        service.syncProjectedResources(note);

        ResourceRecordEntity resource = repository.findByNoteUuid(note.getUserId(), note.getUuid()).getFirst();
        assertEquals(ResourceSourceType.WEB_CLIP, resource.getSourceType());
        assertEquals("https://example.com/new", resource.getSourceUrl());
        assertEquals("新正文", resource.getContent());
    }

    @Test
    void shouldSoftDeleteAllResourcesWhenNoteDeleted() {
        NoteEntity note = new NoteEntity(
                UUID.randomUUID(),
                10L,
                "标题",
                "正文",
                "https://example.com/post",
                1L,
                Collections.emptyList(),
                null,
                "抓取标题",
                null,
                "抓取正文",
                null,
                null,
                null,
                System.currentTimeMillis(),
                false,
                null
        );
        service.syncProjectedResources(note);

        note.softDelete();
        service.syncProjectedResources(note);

        assertEquals(0, repository.findByNoteUuid(note.getUserId(), note.getUuid()).size());
        assertTrue(repository.storage.stream().allMatch(ResourceRecordEntity::isDeleted));
    }

    private static final class InMemoryResourceRecordRepository implements ResourceRecordRepository {

        private final List<ResourceRecordEntity> storage = new ArrayList<>();

        @Override
        public void save(ResourceRecordEntity resourceRecord) {
            storage.add(resourceRecord);
        }

        @Override
        public void update(ResourceRecordEntity resourceRecord) {
            for (int i = 0; i < storage.size(); i++) {
                if (storage.get(i).getUuid().equals(resourceRecord.getUuid())) {
                    storage.set(i, resourceRecord);
                    return;
                }
            }
            storage.add(resourceRecord);
        }

        @Override
        public Optional<ResourceRecordEntity> findByRootUriAndUserId(String rootUri, long userId) {
            return storage.stream()
                    .filter(r -> java.util.Objects.equals(r.getRootUri(), rootUri) && r.getUserId() == userId)
                    .findFirst();
        }

        @Override
        public Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
            return storage.stream()
                    .filter(resource -> resource.getUuid().equals(uuid) && resource.getUserId() == userId)
                    .findFirst();
        }

        @Override
        public List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid) {
            return storage.stream()
                    .filter(resource -> resource.getUserId() == userId)
                    .filter(resource -> noteUuid.equals(resource.getNoteUuid()))
                    .filter(resource -> !resource.isDeleted())
                    .sorted(Comparator.comparingLong(ResourceRecordEntity::getUpdatedAt).reversed())
                    .toList();
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
}