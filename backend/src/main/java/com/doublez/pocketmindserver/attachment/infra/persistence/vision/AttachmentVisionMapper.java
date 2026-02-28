package com.doublez.pocketmindserver.attachment.infra.persistence.vision;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.UUID;

@Mapper
public interface AttachmentVisionMapper extends BaseMapper<AttachmentVisionModel> {

    @Select("""
            SELECT id, uuid, user_id, asset_uuid, note_uuid, content_type,
                   content, model, status, created_at, updated_at, is_deleted
              FROM asset_extractions
             WHERE user_id = #{userId}
               AND status = 'PENDING'
               AND is_deleted = FALSE
             ORDER BY created_at ASC
             LIMIT #{limit}
            """)
    List<AttachmentVisionModel> findPendingByUserId(
            @Param("userId") long userId,
            @Param("limit") int limit);

    @Select("""
            SELECT id, uuid, user_id, asset_uuid, note_uuid, content_type,
                   content, model, status, created_at, updated_at, is_deleted
              FROM asset_extractions
             WHERE user_id = #{userId}
               AND updated_at > #{cursor}
             ORDER BY updated_at ASC
             LIMIT #{limit}
            """)
    List<AttachmentVisionModel> findChangedSince(
            @Param("userId") long userId,
            @Param("cursor") long cursor,
            @Param("limit") int limit);

    @Select("""
            SELECT id, uuid, user_id, asset_uuid, note_uuid, content_type,
                   content, model, status, created_at, updated_at, is_deleted
              FROM asset_extractions
             WHERE user_id = #{userId}
               AND note_uuid = #{noteUuid}
               AND status = 'DONE'
               AND is_deleted = FALSE
             ORDER BY created_at ASC
             LIMIT 200
            """)
    List<AttachmentVisionModel> findDoneByNoteUuid(
            @Param("userId") long userId,
            @Param("noteUuid") UUID noteUuid);

    @Select("""
            SELECT id, uuid, user_id, asset_uuid, note_uuid, content_type,
                   content, model, status, created_at, updated_at, is_deleted
              FROM asset_extractions
             WHERE user_id = #{userId}
               AND asset_uuid = #{assetUuid}
               AND is_deleted = FALSE
             ORDER BY created_at ASC
             LIMIT 200
            """)
    List<AttachmentVisionModel> findAllByAssetsUuid(
            @Param("userId") long userId,
            @Param("assetUuid") UUID noteUuid);
}
