package com.doublez.pocketmindserver.attachment.infra.persistence.vision;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface AttachmentVisionMapper extends BaseMapper<AttachmentVisionModel> {

    @Select("""
            SELECT * FROM asset_extractions
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
            SELECT * FROM asset_extractions
            WHERE user_id = #{userId}
              AND updated_at > #{cursor}
            ORDER BY updated_at ASC
            LIMIT #{limit}
            """)
    List<AttachmentVisionModel> findChangedSince(
            @Param("userId") long userId,
            @Param("cursor") long cursor,
            @Param("limit") int limit);
}
