package com.doublez.pocketmindserver.resource.domain;

import lombok.Data;
import lombok.experimental.Accessors;

import java.time.Instant;
import java.util.UUID;

/**
 * Resource 索引 Outbox 领域实体。
 */
@Data
@Accessors(chain = true)
public class ResourceIndexOutboxEntity {

    private Long id;
    private UUID uuid;
    private Long userId;
    private UUID resourceUuid;
    private String operation;
    private String status;
    private Integer retryCount;
    private Long retryAfter;
    private String lastError;
    private Instant createdAt;
    private Long updatedAt;

    public static ResourceIndexOutboxEntity pending(UUID uuid, long userId, UUID resourceUuid, String operation) {
        long now = System.currentTimeMillis();
        return new ResourceIndexOutboxEntity()
                .setUuid(uuid)
                .setUserId(userId)
                .setResourceUuid(resourceUuid)
                .setOperation(operation)
                .setStatus(ResourceIndexOutboxConstants.STATUS_PENDING)
                .setRetryCount(0)
                .setRetryAfter(now)
                .setUpdatedAt(now);
    }
}
