package com.doublez.pocketmindserver.context.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;
import java.util.Map;

/**
 * context_catalog 表 Mapper。
 */
@Mapper
public interface ContextCatalogMapper extends BaseMapper<ContextCatalogModel> {

  /**
   * 基于 uri 唯一键的原子 UPSERT，避免“先查后插”并发竞态。
   */
  @Insert("""
      INSERT INTO context_catalog (
        uuid, user_id, resource_uuid, context_type, uri, name, abstract_text,
        active_count, updated_at, is_deleted
      ) VALUES (
        #{uuid}, #{userId}, #{resourceUuid}, #{contextType}, #{uri}, #{name}, #{abstractText},
        #{activeCount}, #{updatedAt}, false
      )
      ON CONFLICT (resource_uuid) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        uri = EXCLUDED.uri,
        context_type = EXCLUDED.context_type,
        name = EXCLUDED.name,
        abstract_text = EXCLUDED.abstract_text,
        active_count = context_catalog.active_count,
        updated_at = EXCLUDED.updated_at,
        is_deleted = false
      """)
  int upsertByUri(@Param("uuid") java.util.UUID uuid,
          @Param("userId") Long userId,
          @Param("resourceUuid") java.util.UUID resourceUuid,
          @Param("contextType") String contextType,
          @Param("uri") String uri,
          @Param("name") String name,
          @Param("abstractText") String abstractText,
          @Param("activeCount") Long activeCount,
          @Param("updatedAt") Long updatedAt);

    @Update("UPDATE context_catalog SET is_deleted = true, updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000 WHERE resource_uuid = #{resourceUuid}")
    int deleteByResourceUuid(@Param("resourceUuid") java.util.UUID resourceUuid);

    /**
     * pgvector 余弦相似度搜索。
     */
    @Select("""
            SELECT uri, resource_uuid, context_type, name, abstract_text,
                   active_count, updated_at,
                   1 - (embedding <=> #{queryVector}::vector) AS similarity
            FROM context_catalog
            WHERE user_id = #{userId}
              AND is_deleted = false
              AND embedding IS NOT NULL
              AND (#{contextType} IS NULL OR context_type = #{contextType})
            ORDER BY embedding <=> #{queryVector}::vector
            LIMIT #{limit}
            """)
    List<Map<String, Object>> searchByVector(@Param("queryVector") String queryVector,
                                             @Param("userId") long userId,
                                             @Param("contextType") String contextType,
                                             @Param("limit") int limit);

    /**
     * 更新指定节点的向量嵌入。
     */
    @Update("UPDATE context_catalog SET embedding = #{embedding}::vector WHERE uri = #{uri} AND is_deleted = false")
    int updateEmbedding(@Param("uri") String uri, @Param("embedding") String embedding);
}
