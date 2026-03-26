package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 默认 Note 与 Resource 同步服务实现。
 */
@Service
public class NoteResourceSyncServiceImpl implements NoteResourceSyncService {

    private final NoteResourceProjectionService projectionService;
    private final ResourceRecordRepository resourceRecordRepository;
    private final ResourceCatalogSyncService catalogSyncService;

    public NoteResourceSyncServiceImpl(NoteResourceProjectionService projectionService,
                                       ResourceRecordRepository resourceRecordRepository,
                                       ResourceCatalogSyncService catalogSyncService) {
        this.projectionService = projectionService;
        this.resourceRecordRepository = resourceRecordRepository;
        this.catalogSyncService = catalogSyncService;
    }

    @Override
    @Transactional
    public void syncProjectedResources(NoteEntity note) {
        if (note.isDeleted()) {
            softDeleteByNote(note);
            return;
        }

        List<ResourceRecordEntity> resources = resourceRecordRepository.findByNoteUuid(note.getUserId(), note.getUuid());
        syncNoteText(note, findByType(resources, ResourceSourceType.NOTE_TEXT));
        syncWebClip(note, findByType(resources, ResourceSourceType.WEB_CLIP));
    }

    @Override
    @Transactional
    public void softDeleteByNote(NoteEntity note) {
        softDeleteResources(resourceRecordRepository.findByNoteUuid(note.getUserId(), note.getUuid()));
    }

    private void syncNoteText(NoteEntity note, ResourceRecordEntity existing) {
        if (note.getContent() == null || note.getContent().isBlank()) {
            if (existing != null) {
                softDeleteResources(List.of(existing));
            }
            return;
        }
        if (existing == null) {
            ResourceRecordEntity resource = projectionService.projectNoteText(note);
            resourceRecordRepository.save(resource);
            catalogSyncService.syncToCatalog(resource);
            return;
        }

        String nextTitle = note.getTitle();
        String nextContent = note.getContent();
        if (isUnchanged(existing.getTitle(), nextTitle) && isUnchanged(existing.getContent(), nextContent)) {
            return;
        }

        ResourceRecordEntity resource = existing;
        resource.updateContent(note.getTitle(), note.getContent());
        resourceRecordRepository.update(resource);
        catalogSyncService.syncToCatalog(resource);
    }

    private void syncWebClip(NoteEntity note, ResourceRecordEntity existing) {
        if (note.getPreviewContent() == null || note.getPreviewContent().isBlank()) {
            if (existing != null) {
                softDeleteResources(List.of(existing));
            }
            return;
        }
        if (existing == null) {
            ResourceRecordEntity resource = projectionService.projectWebClip(note);
            resourceRecordRepository.save(resource);
            catalogSyncService.syncToCatalog(resource);
            return;
        }

        String nextTitle = note.getPreviewTitle();
        String nextContent = note.getPreviewContent();
        String nextSourceUrl = note.getSourceUrl();
        if (isUnchanged(existing.getTitle(), nextTitle)
                && isUnchanged(existing.getContent(), nextContent)
                && isUnchanged(existing.getSourceUrl(), nextSourceUrl)) {
            return;
        }

        ResourceRecordEntity resource = existing;
        resource.updateContent(note.getPreviewTitle(), note.getPreviewContent(), note.getSourceUrl());
        resourceRecordRepository.update(resource);
        catalogSyncService.syncToCatalog(resource);
    }

    private ResourceRecordEntity findByType(List<ResourceRecordEntity> resources, ResourceSourceType sourceType) {
        return resources.stream()
                .filter(resource -> resource.getSourceType() == sourceType)
                .findFirst()
                .orElse(null);
    }

    private void softDeleteResources(List<ResourceRecordEntity> resources) {
        for (ResourceRecordEntity resource : resources) {
            resource.softDelete();
            resourceRecordRepository.update(resource);
            catalogSyncService.removeFromCatalog(resource);
        }
    }

    private boolean isUnchanged(String current, String next) {
        return java.util.Objects.equals(current, next);
    }
}
