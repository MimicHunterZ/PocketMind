package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * 默认 Note 到 Resource 投影服务实现。
 */
@Service
public class NoteResourceProjectionServiceImpl implements NoteResourceProjectionService {

    private final ResourceContextService resourceContextService;

    public NoteResourceProjectionServiceImpl(ResourceContextService resourceContextService) {
        this.resourceContextService = resourceContextService;
    }

    @Override
    public ResourceRecordEntity projectNoteText(NoteEntity note) {
        return ResourceRecordEntity.createNoteText(
                UUID.randomUUID(),
                note.getUserId(),
                note.getUuid(),
                resourceContextService.noteTextResource(note.getUserId(), note.getUuid()),
                note.getTitle(),
                note.getContent()
        );
    }

    @Override
    public ResourceRecordEntity projectWebClip(NoteEntity note) {
        return ResourceRecordEntity.createWebClip(
                UUID.randomUUID(),
                note.getUserId(),
                note.getUuid(),
                resourceContextService.webClipResource(note.getUserId(), note.getUuid()),
                note.getSourceUrl(),
                note.getPreviewTitle(),
                note.getPreviewContent()
        );
    }
}
