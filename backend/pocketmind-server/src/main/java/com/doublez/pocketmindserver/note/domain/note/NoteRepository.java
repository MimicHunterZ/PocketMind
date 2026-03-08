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

    /**
     * 增量同步：拉取 updatedAt > cursor 的变更（含软删除）
     */
    List<NoteEntity> findChangedSince(long userId, SyncCursorQuery query);


    /**
     * 同步专用：回填服务端版本号（不修改 updatedAt）。
     */
    void updateServerVersion(UUID uuid, long userId, long serverVersion);

    /**
     * 同步专用：按 UUID 显式软删除笔记并更新 updatedAt。
     * <p>
     * 不能走通用 {@code update()}，否则 {@code @TableLogic} 可能导致
     * {@code is_deleted} 不进入 UPDATE SET。
     */
    void softDeleteByUuidAndUserId(UUID uuid, long userId, long updatedAt);

    /**
     * AI 回调岂用：写入 AI 权威字段（不修改 updatedAt，保证 LWW 正确）。
     */
    void updateAiFields(UUID uuid, long userId, String aiSummary, String resourceStatus,
                        String previewTitle, String previewDescription, String previewContent);

    /**
     * 同步专用：读取笔记关联的标签名称列表。
     */
    List<String> findTagNamesByUuid(UUID noteUuid, long userId);

    /**
     * 同步专用：按客户端最终结果全量替换笔记标签。
     */
    void replaceTagNames(UUID noteUuid, long userId, List<String> tagNames);
}
