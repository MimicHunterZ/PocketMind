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
        uuid, user_id, context_type, uri, parent_uri, name, abstract_text,
        layer, status, is_leaf, active_count, updated_at, is_deleted
      ) VALUES (
        #{uuid}, #{userId}, #{contextType}, #{uri}, #{parentUri}, #{name}, #{abstractText},
        #{layer}, 'ACTIVE', #{isLeaf}, #{activeCount}, #{updatedAt}, false
      )
      ON CONFLICT (uri) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        context_type = EXCLUDED.context_type,
        parent_uri = EXCLUDED.parent_uri,
        name = EXCLUDED.name,
        abstract_text = EXCLUDED.abstract_text,
        layer = EXCLUDED.layer,
        status = 'ACTIVE',
        is_leaf = EXCLUDED.is_leaf,
        updated_at = EXCLUDED.updated_at,
        is_deleted = false
      """)
  int upsertByUri(@Param("uuid") java.util.UUID uuid,
          @Param("userId") Long userId,
          @Param("contextType") String contextType,
          @Param("uri") String uri,
          @Param("parentUri") String parentUri,
          @Param("name") String name,
          @Param("abstractText") String abstractText,
          @Param("layer") String layer,
          @Param("isLeaf") boolean isLeaf,
          @Param("activeCount") Long activeCount,
          @Param("updatedAt") Long updatedAt);

    /**
     * pgvector 余弦相似度搜索。
     */
    @Select("""
            SELECT uri, parent_uri, context_type, layer, name, abstract_text,
                   active_count, updated_at, is_leaf,
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
     * pgvector 余弦相似度：限定 parentUri 搜索子节点。
     */
    @Select("""
            SELECT uri, parent_uri, context_type, layer, name, abstract_text,
                   active_count, updated_at, is_leaf,
                   1 - (embedding <=> #{queryVector}::vector) AS similarity
            FROM context_catalog
            WHERE parent_uri = #{parentUri}
              AND user_id = #{userId}
              AND is_deleted = false
              AND embedding IS NOT NULL
            ORDER BY embedding <=> #{queryVector}::vector
            LIMIT #{limit}
            """)
    List<Map<String, Object>> searchChildrenByVector(@Param("queryVector") String queryVector,
                                                     @Param("parentUri") String parentUri,
                                                     @Param("userId") long userId,
                                                     @Param("limit") int limit);

    /**
     * 更新指定节点的向量嵌入。
     */
    @Update("UPDATE context_catalog SET embedding = #{embedding}::vector WHERE uri = #{uri} AND is_deleted = false")
    int updateEmbedding(@Param("uri") String uri, @Param("embedding") String embedding);
}
