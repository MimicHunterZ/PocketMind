package com.doublez.pocketmindserver.note.infra.persistence.note;

import com.doublez.pocketmindserver.note.infra.persistence.tag.TagModel;
import org.apache.ibatis.annotations.*;

import java.util.List;
import java.util.UUID;

/**
 * note_tag_relation 表 MyBatis Mapper（复合主键，不继承 BaseMapper）
 */
@Mapper
public interface NoteTagRelationMapper {

    /** 为笔记添加标签（ON CONFLICT DO NOTHING 保证幂等） */
    @Insert("INSERT INTO note_tag_relation(note_uuid, tag_id) VALUES(#{noteUuid}, #{tagId}) ON CONFLICT DO NOTHING")
    void insert(@Param("noteUuid") UUID noteUuid, @Param("tagId") long tagId);

    /** 删除笔记的某个标签 */
    @Delete("DELETE FROM note_tag_relation WHERE note_uuid = #{noteUuid} AND tag_id = #{tagId}")
    void delete(@Param("noteUuid") UUID noteUuid, @Param("tagId") long tagId);

    /** 清空笔记的所有标签 */
    @Delete("DELETE FROM note_tag_relation WHERE note_uuid = #{noteUuid}")
    void deleteByNoteUuid(@Param("noteUuid") UUID noteUuid);

    /**
     * 查询某条笔记关联的所有 tagId（JOIN tags 表过滤 userId 防止越权）
     */
    @Select("""
            SELECT r.tag_id
              FROM note_tag_relation r
              JOIN tags t ON t.id = r.tag_id
             WHERE r.note_uuid = #{noteUuid}
               AND t.user_id = #{userId}
                                                         AND t.is_deleted = FALSE
            """)
    List<Long> findTagIdsByNoteUuid(@Param("userId") long userId, @Param("noteUuid") UUID noteUuid);

    /**
     * 查询某条笔记关联的所有标签（JOIN tags 表过滤 userId 防止越权）
     */
    @Select("""
            SELECT t.id, t.uuid, t.user_id, t.name, t.created_at, t.updated_at, t.is_deleted
              FROM tags t
              JOIN note_tag_relation r ON t.id = r.tag_id
             WHERE r.note_uuid = #{noteUuid}
               AND t.user_id = #{userId}
               AND t.is_deleted = FALSE
            """)
    @Results(id = "tagResultMap", value = {
            @Result(column = "id",         property = "id"),
            @Result(column = "uuid",       property = "uuid"),
            @Result(column = "user_id",    property = "userId"),
            @Result(column = "name",       property = "name"),
            @Result(column = "created_at", property = "createdAt"),
            @Result(column = "updated_at", property = "updatedAt"),
            @Result(column = "is_deleted", property = "isDeleted")
    })
    List<TagModel> findTagsByNoteUuid(@Param("userId") long userId, @Param("noteUuid") UUID noteUuid);
}
