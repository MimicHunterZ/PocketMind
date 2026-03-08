package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;

/**
 * Note 与 Resource 的同步编排服务。
 */
public interface NoteResourceSyncService {

    void syncProjectedResources(NoteEntity note);

    void softDeleteByNote(NoteEntity note);
}
