package com.doublez.pocketmindserver.resource.application;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Resource 同步一致性策略测试。
 */
class ResourceSyncConsistencyPolicyTest {

    @Test
    void shouldUseDatabaseOutboxAsDefaultBackend() {
        ResourceSyncConsistencyPolicy policy = ResourceSyncConsistencyPolicy.defaultPolicy();

        assertEquals(ResourceSyncConsistencyPolicy.OutboxBackend.POSTGRES_TABLE, policy.outboxBackend());
        assertTrue(policy.enableCatalogAsyncIndexing());
        assertTrue(policy.enableRetrievalFallbackToResourceRecords());
    }

    @Test
    void shouldRecognizeCatalogAsRebuildableIndexLayer() {
        ResourceSyncConsistencyPolicy policy = ResourceSyncConsistencyPolicy.defaultPolicy();

        assertFalse(policy.catalogIsSourceOfTruth());
    }
}
