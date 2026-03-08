package com.doublez.pocketmindserver.note.infra.persistence.note;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;

/**
 * notes 表的 MyBatis-Plus Mapper
 */
@Mapper
public interface NoteMapper extends BaseMapper<NoteModel> {

    /**
     * PostgreSQL 全文搜索（title + content + preview_title + preview_content）
     */
    @Select("""
            SELECT id, uuid, user_id, title, content, source_url, category_id,
                   note_time, preview_title, preview_description, preview_content,
                   resource_status, summary, memory_path, created_at, updated_at, is_deleted, server_version
              FROM notes
             WHERE user_id = #{userId}
               AND is_deleted = FALSE
               AND to_tsvector('simple',
                     COALESCE(title, '') || ' ' ||
                     COALESCE(content, '') || ' ' ||
                     COALESCE(preview_title, '') || ' ' ||
                     COALESCE(preview_content, ''))
                   @@ plainto_tsquery('simple', #{query})
             ORDER BY updated_at DESC
             LIMIT #{limit} OFFSET #{offset}
            """)
    List<NoteModel> fullTextSearch(
            @Param("userId") long userId,
            @Param("query") String query,
            @Param("limit") int limit,
            @Param("offset") int offset);

    /**
     * 增量同步：获取 updatedAt > cursor 的全部记录（含软删除）
     * 注意：绕过 @TableLogic 自动过滤，同步需要包含已删除记录
     */
    @Select("""
            SELECT id, uuid, user_id, title, content, source_url, category_id,
                   note_time, preview_title, preview_description, preview_content,
                   resource_status, summary, memory_path, created_at, updated_at, is_deleted, server_version
              FROM notes
             WHERE user_id = #{userId}
               AND updated_at > #{cursor}
             ORDER BY updated_at ASC
             LIMIT #{limit}
            """)
    List<NoteModel> findChangedSince(
            @Param("userId") long userId,
            @Param("cursor") long cursor,
            @Param("limit") int limit);

    /**
     * 同步回填 server_version（不动 updatedAt）。
     */
    @Update("""
            UPDATE notes
               SET server_version = #{serverVersion}
             WHERE uuid = #{uuid}
               AND user_id = #{userId}
            """)
    int updateServerVersion(@Param("uuid") java.util.UUID uuid,
                            @Param("userId") long userId,
                            @Param("serverVersion") long serverVersion);

    /**
     * 同步删除：显式写入 is_deleted，绕过 @TableLogic 自动更新限制。
     */
    @Update("""
            UPDATE notes
               SET is_deleted = TRUE,
                   updated_at = #{updatedAt}
             WHERE uuid = #{uuid}
               AND user_id = #{userId}
            """)
    int softDeleteByUuidAndUserId(@Param("uuid") java.util.UUID uuid,
                                  @Param("userId") long userId,
                                  @Param("updatedAt") long updatedAt);

    /**
     * AI 回调：更新 AI 权威字段（不动 updated_at，保证 LWW 正确）。
     */
    @Update("""
            UPDATE notes
               SET summary             = #{aiSummary},
                   resource_status     = #{resourceStatus},
                   preview_title       = #{previewTitle},
                   preview_description = #{previewDescription},
                   preview_content     = #{previewContent}
             WHERE uuid    = #{uuid}
               AND user_id = #{userId}
            """)
    int updateAiFields(@Param("uuid") java.util.UUID uuid,
                       @Param("userId") long userId,
                       @Param("aiSummary") String aiSummary,
                       @Param("resourceStatus") String resourceStatus,
                       @Param("previewTitle") String previewTitle,
                       @Param("previewDescription") String previewDescription,
                       @Param("previewContent") String previewContent);
}
