package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;

/**
 * Note 到 Resource 的投影服务。
 */
public interface NoteResourceProjectionService {

    ResourceRecordEntity projectNoteText(NoteEntity note);

    ResourceRecordEntity projectWebClip(NoteEntity note);
}
