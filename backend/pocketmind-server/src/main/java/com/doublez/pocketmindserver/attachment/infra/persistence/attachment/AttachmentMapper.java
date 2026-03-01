package com.doublez.pocketmindserver.attachment.infra.persistence.attachment;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface AttachmentMapper extends BaseMapper<AttachmentModel> {

    @Select("""
            SELECT id, uuid, user_id, note_uuid, type, mime, storage_key,
                   storage_type, sha256, source, created_at, updated_at, is_deleted
              FROM assets
             WHERE user_id = #{userId}
               AND updated_at > #{cursor}
             ORDER BY updated_at ASC
             LIMIT #{limit}
            """)
    List<AttachmentModel> findChangedSince(
            @Param("userId") long userId,
            @Param("cursor") long cursor,
            @Param("limit") int limit);
}
