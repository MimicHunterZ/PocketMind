package com.doublez.pocketmindserver.chat.infra.persistence.session;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.UUID;

@Mapper
public interface ChatSessionMapper extends BaseMapper<ChatSessionModel> {

    @Select("""
            SELECT id, uuid, user_id, scope_note_uuid, title, memory_snapshot,
                   created_at, updated_at, is_deleted
              FROM chat_sessions
             WHERE user_id = #{userId}
               AND scope_note_uuid = #{noteUuid}
               AND is_deleted = FALSE
             ORDER BY updated_at DESC
             LIMIT 100
            """)
    List<ChatSessionModel> findByNoteUuid(
            @Param("userId") long userId,
            @Param("noteUuid") UUID noteUuid);

    @Select("""
            SELECT id, uuid, user_id, scope_note_uuid, title, memory_snapshot,
                   created_at, updated_at, is_deleted
              FROM chat_sessions
             WHERE user_id = #{userId}
               AND updated_at > #{cursor}
             ORDER BY updated_at ASC
             LIMIT #{limit}
            """)
    List<ChatSessionModel> findChangedSince(
            @Param("userId") long userId,
            @Param("cursor") long cursor,
            @Param("limit") int limit);
}
