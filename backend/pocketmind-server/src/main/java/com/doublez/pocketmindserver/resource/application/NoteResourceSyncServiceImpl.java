package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxConstants;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import com.doublez.pocketmindserver.resource.application.mq.ResourceOutboxHintEvent;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * 默认 Note 与 Resource 同步服务实现。
 */
@Service
public class NoteResourceSyncServiceImpl implements NoteResourceSyncService {

    private final NoteResourceProjectionService projectionService;
    private final ResourceRecordRepository resourceRecordRepository;
    private final ResourceIndexOutboxRepository outboxRepository;
    private final ApplicationEventPublisher applicationEventPublisher;

    public NoteResourceSyncServiceImpl(NoteResourceProjectionService projectionService,
                                       ResourceRecordRepository resourceRecordRepository,
                                       ResourceIndexOutboxRepository outboxRepository,
                                       ApplicationEventPublisher applicationEventPublisher) {
        this.projectionService = projectionService;
        this.resourceRecordRepository = resourceRecordRepository;
        this.outboxRepository = outboxRepository;
        this.applicationEventPublisher = applicationEventPublisher;
    }

    @Override
    @Transactional
    public void syncProjectedResources(NoteEntity note) {
        if (note.isDeleted()) {
            softDeleteByNote(note);
            return;
        }

        List<ResourceRecordEntity> resources = resourceRecordRepository.findByNoteUuid(note.getUserId(), note.getUuid());
        if (hasSourceUrl(note)) {
            ResourceRecordEntity noteText = findByType(resources, ResourceSourceType.NOTE_TEXT);
            if (noteText != null) {
                softDeleteResources(List.of(noteText));
            }
            syncWebClip(note, findByType(resources, ResourceSourceType.WEB_CLIP));
            return;
        }
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
            appendOutbox(resource, ResourceIndexOutboxConstants.OPERATION_UPSERT);
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
        appendOutbox(resource, ResourceIndexOutboxConstants.OPERATION_UPSERT);
    }

    private void syncWebClip(NoteEntity note, ResourceRecordEntity existing) {
        String nextTitle = resolveWebClipTitle(note);
        String nextContent = resolveWebClipContent(note);
        String nextSourceUrl = note.getSourceUrl();
        if (nextContent == null || nextContent.isBlank()) {
            if (existing != null) {
                softDeleteResources(List.of(existing));
            }
            return;
        }
        if (existing == null) {
            ResourceRecordEntity resource = projectionService.projectWebClip(note);
            resourceRecordRepository.save(resource);
            appendOutbox(resource, ResourceIndexOutboxConstants.OPERATION_UPSERT);
            return;
        }

        if (isUnchanged(existing.getTitle(), nextTitle)
                && isUnchanged(existing.getContent(), nextContent)
                && isUnchanged(existing.getSourceUrl(), nextSourceUrl)) {
            return;
        }

        ResourceRecordEntity resource = existing;
        resource.updateContent(nextTitle, nextContent, nextSourceUrl);
        resourceRecordRepository.update(resource);
        appendOutbox(resource, ResourceIndexOutboxConstants.OPERATION_UPSERT);
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
            appendOutbox(resource, ResourceIndexOutboxConstants.OPERATION_DELETE);
        }
    }

    private boolean isUnchanged(String current, String next) {
        return java.util.Objects.equals(current, next);
    }

    private boolean hasSourceUrl(NoteEntity note) {
        return note.getSourceUrl() != null && !note.getSourceUrl().isBlank();
    }

    private String resolveWebClipTitle(NoteEntity note) {
        if (note.getPreviewTitle() != null && !note.getPreviewTitle().isBlank()) {
            return note.getPreviewTitle();
        }
        return note.getTitle();
    }

    private String resolveWebClipContent(NoteEntity note) {
        if (note.getPreviewContent() != null && !note.getPreviewContent().isBlank()) {
            return note.getPreviewContent();
        }
        if (hasSourceUrl(note)) {
            return note.getContent();
        }
        return null;
    }

    private void appendOutbox(ResourceRecordEntity resource, String operation) {
        UUID eventUuid = UUID.randomUUID();
        outboxRepository.appendPending(eventUuid, resource.getUserId(), resource.getUuid(), operation);
        applicationEventPublisher.publishEvent(new ResourceOutboxHintEvent(
                eventUuid,
                resource.getUserId(),
                resource.getUuid(),
                operation,
                System.currentTimeMillis()
        ));
    }
}
