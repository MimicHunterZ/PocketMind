package com.doublez.pocketmindserver.note.infra.persistence.tag;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Update;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.UUID;

/**
 * tags 表 MyBatis Mapper
 */
@Mapper
public interface TagMapper extends BaseMapper<TagModel> {

    /**
     * 插入标签，若 (user_id, name) 已存在则静默忽略（保证幂等）。
     * 对应 findOrCreate 的写操作。
     */
    @Insert("""
            INSERT INTO tags(uuid, user_id, name, updated_at, is_deleted)
            VALUES(#{uuid}, #{userId}, #{name}, #{updatedAt}, FALSE)
            ON CONFLICT (user_id, name) WHERE is_deleted = FALSE DO NOTHING
            """)
    void insertIgnoreConflict(@Param("uuid") UUID uuid,
                              @Param("userId") long userId,
                              @Param("name") String name,
                              @Param("updatedAt") long updatedAt);

    /**
     * 显式软删除标签，绕过 @TableLogic 自动更新限制。
     */
    @Update("""
            UPDATE tags
               SET is_deleted = TRUE,
                   updated_at = #{updatedAt}
             WHERE uuid = #{uuid}
               AND user_id = #{userId}
            """)
    int softDeleteByUuidAndUserId(@Param("uuid") UUID uuid,
                                  @Param("userId") long userId,
                                  @Param("updatedAt") long updatedAt);
}
