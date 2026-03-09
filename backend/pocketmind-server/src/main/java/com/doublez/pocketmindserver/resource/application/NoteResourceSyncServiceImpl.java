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
        syncNoteText(note);
        syncWebClip(note);
    }

    @Override
    @Transactional
    public void softDeleteByNote(NoteEntity note) {
        softDeleteResources(resourceRecordRepository.findByNoteUuid(note.getUserId(), note.getUuid()));
    }

    private void syncNoteText(NoteEntity note) {
        List<ResourceRecordEntity> existing = findByType(note, ResourceSourceType.NOTE_TEXT);
        if (note.getContent() == null || note.getContent().isBlank()) {
            softDeleteResources(existing);
            return;
        }
        if (existing.isEmpty()) {
            ResourceRecordEntity resource = projectionService.projectNoteText(note);
            resourceRecordRepository.save(resource);
            catalogSyncService.syncToCatalog(resource);
            return;
        }
        ResourceRecordEntity resource = existing.getFirst();
        resource.updateContent(note.getTitle(), note.getContent());
        resourceRecordRepository.update(resource);
        catalogSyncService.syncToCatalog(resource);
    }

    private void syncWebClip(NoteEntity note) {
        List<ResourceRecordEntity> existing = findByType(note, ResourceSourceType.WEB_CLIP);
        if (note.getPreviewContent() == null || note.getPreviewContent().isBlank()) {
            softDeleteResources(existing);
            return;
        }
        if (existing.isEmpty()) {
            ResourceRecordEntity resource = projectionService.projectWebClip(note);
            resourceRecordRepository.save(resource);
            catalogSyncService.syncToCatalog(resource);
            return;
        }
        ResourceRecordEntity resource = existing.getFirst();
        resource.updateContent(note.getPreviewTitle(), note.getPreviewContent(), note.getSourceUrl());
        resourceRecordRepository.update(resource);
        catalogSyncService.syncToCatalog(resource);
    }

    private List<ResourceRecordEntity> findByType(NoteEntity note, ResourceSourceType sourceType) {
        return resourceRecordRepository.findByNoteUuid(note.getUserId(), note.getUuid())
                .stream()
                .filter(resource -> resource.getSourceType() == sourceType)
                .toList();
    }

    private void softDeleteResources(List<ResourceRecordEntity> resources) {
        for (ResourceRecordEntity resource : resources) {
            resource.softDelete();
            resourceRecordRepository.update(resource);
            catalogSyncService.removeFromCatalog(resource);
        }
    }
}
