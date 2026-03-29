package com.doublez.pocketmindserver.resource.domain;

import java.util.List;
import java.util.UUID;

/**
 * Resource 索引 Outbox 仓储接口。
 */
public interface ResourceIndexOutboxRepository {

    void appendPending(UUID eventUuid, long userId, UUID resourceUuid, String operation);

    List<ResourceIndexOutboxEntity> pollRunnable(long nowEpochMillis, int limit);

    default List<ResourceIndexOutboxEntity> claimRunnable(long nowEpochMillis, int limit) {
        return pollRunnable(nowEpochMillis, limit);
    }

    default int recoverStaleProcessing(long nowEpochMillis, long processingLeaseMillis) {
        return 0;
    }

    void markCompleted(UUID eventUuid);

    void markFailed(UUID eventUuid, long nextRetryAfterEpochMillis, String errorMessage);
}
