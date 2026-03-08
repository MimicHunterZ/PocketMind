package com.doublez.pocketmindserver.sync.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.Optional;

@Mapper
public interface SyncChangeLogMapper extends BaseMapper<SyncChangeLogModel> {

    /**
     * 增量 Pull 核心查询：按 (user_id, id) 索引拉取 sinceVersion 之后的变更，
     * 结果按 id 升序排列，确保客户端游标推进正确。
     *
     * @param sinceVersion 上一次 Pull 的游标（不含），即 SyncCheckpoint.lastPulledVersion
     * @param limit        最大返回行数（通常为 pageSize + 1，用于检测 hasMore）
     */
    @Select("""
            SELECT id, user_id, entity_type, entity_uuid, operation,
                   updated_at, client_mutation_id, payload, created_at
              FROM sync_change_log
             WHERE user_id = #{userId}
               AND id > #{sinceVersion}
             ORDER BY id ASC
             LIMIT #{limit}
            """)
    List<SyncChangeLogModel> findSince(
            @Param("userId") long userId,
            @Param("sinceVersion") long sinceVersion,
            @Param("limit") int limit);

    /**
     * 幂等性校验：按 client_mutation_id 查询，若存在则直接返回原始 serverVersion。
     */
    @Select("""
            SELECT id
              FROM sync_change_log
             WHERE client_mutation_id = #{mutationId}
             LIMIT 1
            """)
    Optional<Long> findVersionByMutationId(@Param("mutationId") String mutationId);
}
