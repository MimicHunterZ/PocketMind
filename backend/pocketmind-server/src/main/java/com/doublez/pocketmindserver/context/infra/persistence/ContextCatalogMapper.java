package com.doublez.pocketmindserver.context.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
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
