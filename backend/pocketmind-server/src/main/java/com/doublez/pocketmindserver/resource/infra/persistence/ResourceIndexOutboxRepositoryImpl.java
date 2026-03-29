package com.doublez.pocketmindserver.resource.infra.persistence;

import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxConstants;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Resource 索引 Outbox 仓储实现。
 */
@Repository
@RequiredArgsConstructor
public class ResourceIndexOutboxRepositoryImpl implements ResourceIndexOutboxRepository {

    private final ResourceIndexOutboxMapper mapper;

    @Override
    public void appendPending(UUID eventUuid, long userId, UUID resourceUuid, String operation) {
        ResourceIndexOutboxModel model = new ResourceIndexOutboxModel()
                .setUuid(eventUuid)
                .setUserId(userId)
                .setResourceUuid(resourceUuid)
                .setOperation(operation)
                .setStatus(ResourceIndexOutboxConstants.STATUS_PENDING)
                .setRetryCount(0)
                .setRetryAfter(System.currentTimeMillis())
                .setUpdatedAt(System.currentTimeMillis());
        mapper.insert(model);
    }

    @Override
    public List<ResourceIndexOutboxEntity> pollRunnable(long nowEpochMillis, int limit) {
        return mapper.findRunnable(nowEpochMillis, limit).stream().map(this::toEntity).toList();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public List<ResourceIndexOutboxEntity> claimRunnable(long nowEpochMillis, int limit) {
        List<ResourceIndexOutboxModel> candidates = mapper.claimRunnableForUpdate(nowEpochMillis, limit);
        List<ResourceIndexOutboxModel> claimed = new java.util.ArrayList<>();
        for (ResourceIndexOutboxModel candidate : candidates) {
            if (candidate.getId() == null) {
                continue;
            }
            int updated = mapper.markProcessingById(candidate.getId());
            if (updated == 1) {
                candidate.setStatus(ResourceIndexOutboxConstants.STATUS_PROCESSING);
                claimed.add(candidate);
            }
        }
        return claimed.stream().map(this::toEntity).toList();
    }

    @Override
    public int recoverStaleProcessing(long nowEpochMillis, long processingLeaseMillis) {
        long safeLeaseMillis = Math.max(1L, processingLeaseMillis);
        long staleBeforeMillis = nowEpochMillis - safeLeaseMillis;
        return mapper.recoverStaleProcessing(staleBeforeMillis);
    }

    @Override
    public void markCompleted(UUID eventUuid) {
        mapper.markCompleted(eventUuid);
    }

    @Override
    public void markFailed(UUID eventUuid, long nextRetryAfterEpochMillis, String errorMessage) {
        mapper.markFailed(eventUuid, nextRetryAfterEpochMillis, errorMessage);
    }

    private ResourceIndexOutboxEntity toEntity(ResourceIndexOutboxModel model) {
        return new ResourceIndexOutboxEntity()
                .setId(model.getId())
                .setUuid(model.getUuid())
                .setUserId(model.getUserId())
                .setResourceUuid(model.getResourceUuid())
                .setOperation(model.getOperation())
                .setStatus(model.getStatus())
                .setRetryCount(model.getRetryCount())
                .setRetryAfter(model.getRetryAfter())
                .setLastError(model.getLastError())
                .setCreatedAt(model.getCreatedAt())
                .setUpdatedAt(model.getUpdatedAt());
    }
}
