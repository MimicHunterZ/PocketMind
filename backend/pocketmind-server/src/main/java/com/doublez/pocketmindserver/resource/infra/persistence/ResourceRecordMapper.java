package com.doublez.pocketmindserver.resource.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.UUID;

@Mapper
public interface ResourceRecordMapper extends BaseMapper<ResourceRecordModel> {

    @Select("""
            SELECT id, uuid, user_id, source_type, root_uri, title, content, source_url,
                   note_uuid, session_uuid, asset_uuid, status, created_at, updated_at, is_deleted
              FROM resource_records
             WHERE user_id = #{userId}
               AND note_uuid = #{noteUuid}
               AND is_deleted = FALSE
             ORDER BY updated_at DESC
            """)
    List<ResourceRecordModel> findByNoteUuid(@Param("userId") long userId,
                                             @Param("noteUuid") UUID noteUuid);

    @Select("""
            SELECT id, uuid, user_id, source_type, root_uri, title, content, source_url,
                   note_uuid, session_uuid, asset_uuid, status, created_at, updated_at, is_deleted
              FROM resource_records
             WHERE user_id = #{userId}
               AND session_uuid = #{sessionUuid}
               AND is_deleted = FALSE
             ORDER BY updated_at DESC
            """)
    List<ResourceRecordModel> findBySessionUuid(@Param("userId") long userId,
                                                @Param("sessionUuid") UUID sessionUuid);

    @Select("""
            SELECT id, uuid, user_id, source_type, root_uri, title, content, source_url,
                   note_uuid, session_uuid, asset_uuid, status, created_at, updated_at, is_deleted
              FROM resource_records
             WHERE user_id = #{userId}
               AND asset_uuid = #{assetUuid}
               AND is_deleted = FALSE
             ORDER BY updated_at DESC
            """)
    List<ResourceRecordModel> findByAssetUuid(@Param("userId") long userId,
                                              @Param("assetUuid") UUID assetUuid);
}
