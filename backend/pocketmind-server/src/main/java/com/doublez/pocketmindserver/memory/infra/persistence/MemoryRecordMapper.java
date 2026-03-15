package com.doublez.pocketmindserver.memory.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * memory_records Mapper。
 */
@Mapper
public interface MemoryRecordMapper extends BaseMapper<MemoryRecordModel> {

    /**
     * 原子递增 active_count。
     */
    @Update("UPDATE memory_records SET active_count = active_count + 1 WHERE uuid = #{uuid} AND user_id = #{userId} AND is_deleted = false")
    int incrementActiveCount(@Param("uuid") UUID uuid, @Param("userId") long userId);

    /**
     * pgvector 余弦相似度搜索记忆。
     */
    @Select("""
            SELECT uuid, user_id, memory_type, root_uri, title, abstract_text,
                   content, active_count, status, updated_at,
                   1 - (embedding <=> #{queryVector}::vector) AS similarity
            FROM memory_records
            WHERE user_id = #{userId}
              AND is_deleted = false
              AND status = 'ACTIVE'
              AND embedding IS NOT NULL
            ORDER BY embedding <=> #{queryVector}::vector
            LIMIT #{limit}
            """)
    List<Map<String, Object>> searchByVector(@Param("queryVector") String queryVector,
                                             @Param("userId") long userId,
                                             @Param("limit") int limit);

    /**
     * 更新指定记忆的向量嵌入。
     */
    @Update("UPDATE memory_records SET embedding = #{embedding}::vector WHERE uuid = #{uuid} AND user_id = #{userId} AND is_deleted = false")
    int updateEmbedding(@Param("uuid") UUID uuid, @Param("userId") long userId, @Param("embedding") String embedding);
}
