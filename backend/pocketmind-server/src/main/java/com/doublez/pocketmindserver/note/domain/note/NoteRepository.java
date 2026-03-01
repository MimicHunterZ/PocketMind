package com.doublez.pocketmindserver.note.domain.note;

import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 笔记仓库接口（领域层定义，infra 层实现）
 */
public interface NoteRepository {

    void save(NoteEntity note);

    void update(NoteEntity note);

    Optional<NoteEntity> findByUuidAndUserId(UUID uuid, long userId);

    List<NoteEntity> findByUserId(long userId, PageQuery pageQuery);

    /**
     * 全文搜索（title + content + preview_content + preview_title）
     * 使用 PostgreSQL to_tsvector FTS
     */
    List<NoteEntity> searchByText(long userId, String query, PageQuery pageQuery);

    /**
     * 增量同步：拉取 updatedAt > cursor 的变更（含软删除）
     */
    List<NoteEntity> findChangedSince(long userId, SyncCursorQuery query);

    /**
     * 按 UUID 列表批量查询
     */
    List<NoteEntity> findByUuids(long userId, List<UUID> uuids);
}
