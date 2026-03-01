package com.doublez.pocketmindserver.note.infra.persistence.note;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

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
                   resource_status, summary, memory_path, created_at, updated_at, is_deleted
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
                   resource_status, summary, memory_path, created_at, updated_at, is_deleted
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
}
