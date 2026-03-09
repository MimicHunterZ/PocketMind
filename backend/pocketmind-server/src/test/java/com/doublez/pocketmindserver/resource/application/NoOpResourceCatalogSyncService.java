package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;

/**
 * 无操作的 ResourceCatalogSyncService — 仅用于单元测试中避免真实目录同步。
 */
class NoOpResourceCatalogSyncService implements ResourceCatalogSyncService {

    @Override
    public void syncToCatalog(ResourceRecordEntity resource) {
        // 测试中不执行目录同步
    }

    @Override
    public void removeFromCatalog(ResourceRecordEntity resource) {
        // 测试中不执行目录删除
    }
}
