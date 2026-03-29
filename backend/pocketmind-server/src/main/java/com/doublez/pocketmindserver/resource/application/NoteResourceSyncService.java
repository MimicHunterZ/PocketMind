package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;

/**
 * Note 与 Resource 的同步编排服务。
 */
public interface NoteResourceSyncService {

    /**
     * 返回当前 Resource 同步一致性策略。
     */
    default ResourceSyncConsistencyPolicy consistencyPolicy() {
        return ResourceSyncConsistencyPolicy.defaultPolicy();
    }

    void syncProjectedResources(NoteEntity note);

    void softDeleteByNote(NoteEntity note);
}
