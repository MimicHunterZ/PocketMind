package com.doublez.pocketmindserver.resource.application;

/**
 * Resource 同步一致性策略。
 */
public record ResourceSyncConsistencyPolicy(
        OutboxBackend outboxBackend,
        boolean enableCatalogAsyncIndexing,
        boolean enableRetrievalFallbackToResourceRecords,
        boolean catalogIsSourceOfTruth
) {

    /**
     * Outbox 后端类型。
     */
    public enum OutboxBackend {
        POSTGRES_TABLE,
        REDIS,
        MQ
    }

    /**
     * 默认策略：PostgreSQL 同库 Outbox + catalog 异步索引 + retrieval 降级。
     */
    public static ResourceSyncConsistencyPolicy defaultPolicy() {
        return new ResourceSyncConsistencyPolicy(
                OutboxBackend.POSTGRES_TABLE,
                true,
                true,
                false
        );
    }
}
