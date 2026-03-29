package com.doublez.pocketmindserver.resource.infra.persistence;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;
import java.util.UUID;

/**
 * Resource 索引 Outbox Mapper。
 */
@Mapper
public interface ResourceIndexOutboxMapper extends BaseMapper<ResourceIndexOutboxModel> {

    @Select("""
            SELECT id, uuid, user_id, resource_uuid, operation, status,
                   retry_count, retry_after, last_error, created_at, updated_at
              FROM resource_index_outbox
             WHERE status = 'PENDING'
               AND retry_after <= #{nowEpochMillis}
             ORDER BY id ASC
             LIMIT #{limit}
            """)
    List<ResourceIndexOutboxModel> findRunnable(@Param("nowEpochMillis") long nowEpochMillis,
                                                 @Param("limit") int limit);

    @Select("""
            SELECT id, uuid, user_id, resource_uuid, operation, status,
                   retry_count, retry_after, last_error, created_at, updated_at
              FROM resource_index_outbox
             WHERE status = 'PENDING'
               AND retry_after <= #{nowEpochMillis}
             ORDER BY id ASC
             LIMIT #{limit}
             FOR UPDATE SKIP LOCKED
            """)
    List<ResourceIndexOutboxModel> claimRunnableForUpdate(@Param("nowEpochMillis") long nowEpochMillis,
                                                           @Param("limit") int limit);

    @Update("""
            UPDATE resource_index_outbox
               SET status = 'PROCESSING',
                   updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
             WHERE id = #{id}
               AND status = 'PENDING'
            """)
    int markProcessingById(@Param("id") long id);

    @Update("""
            UPDATE resource_index_outbox
               SET status = 'COMPLETED', updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
              WHERE uuid = #{eventUuid}
               AND status = 'PROCESSING'
            """)
    int markCompleted(@Param("eventUuid") UUID eventUuid);

    @Update("""
            UPDATE resource_index_outbox
               SET status = 'PENDING',
                   retry_count = retry_count + 1,
                   retry_after = #{nextRetryAfter},
                   last_error = #{errorMessage},
                   updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
              WHERE uuid = #{eventUuid}
               AND status = 'PROCESSING'
            """)
    int markFailed(@Param("eventUuid") UUID eventUuid,
                   @Param("nextRetryAfter") long nextRetryAfter,
                   @Param("errorMessage") String errorMessage);

    @Update("""
            UPDATE resource_index_outbox
               SET status = 'PENDING',
                   updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
             WHERE status = 'PROCESSING'
               AND updated_at <= #{staleBeforeMillis}
            """)
    int recoverStaleProcessing(@Param("staleBeforeMillis") long staleBeforeMillis);
}
