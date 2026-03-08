package com.doublez.pocketmindserver.sync.infra.persistence;

import com.doublez.pocketmindserver.sync.domain.SyncChangeLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;


@Repository
@RequiredArgsConstructor
public class MybatisSyncChangeLogRepository implements SyncChangeLogRepository {

    private final SyncChangeLogMapper mapper;

    /**
     * 插入变更日志并返回自增主键（serverVersion）。
     * MyBatis-Plus insert() 会将生成的 id 回填至 model.id。
     */
    @Override
    public long insert(long userId,
                       String entityType,
                       UUID entityUuid,
                       String operation,
                       long updatedAt,
                       String clientMutationId,
                       String payloadJson) {
        SyncChangeLogModel model = new SyncChangeLogModel()
                .setUserId(userId)
                .setEntityType(entityType)
                .setEntityUuid(entityUuid)
                .setOperation(operation)
                .setUpdatedAt(updatedAt)
                .setClientMutationId(clientMutationId)
                .setPayload(payloadJson);
        mapper.insert(model);
        // MyBatis-Plus 的 @TableId(type = IdType.AUTO) 在 insert 后回填生成的 id
        return model.getId();
    }

    @Override
    public Optional<Long> findVersionByMutationId(String mutationId) {
        if (mutationId == null || mutationId.isBlank()) return Optional.empty();
        return mapper.findVersionByMutationId(mutationId);
    }

    @Override
    public List<SyncChangeLogModel> findSince(long userId, long sinceVersion, int limit) {
        return mapper.findSince(userId, sinceVersion, limit);
    }
}
