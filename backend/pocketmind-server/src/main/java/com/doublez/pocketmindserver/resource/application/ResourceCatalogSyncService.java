package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;

/**
 * Resource → ContextCatalog 同步服务。
 *
 * <p>当 Resource 被创建或更新时，自动在 context_catalog 中维护对应的节点条目，
 * 使层级检索器（{@code HierarchicalRetriever}）能够发现并检索该 Resource。
 */
public interface ResourceCatalogSyncService {

    /**
     * 将 Resource 同步至 context_catalog。
     *
     * <p>包含以下操作：
     * <ol>
     *   <li>确保 Resource 根目录节点存在</li>
     *   <li>确保来源分组目录节点存在（如 {@code notes/}, {@code chats/}）</li>
     *   <li>upsert Resource 自身作为叶子节点</li>
     * </ol>
     *
     * @param resource 已保存/更新的 Resource 实体
     */
    void syncToCatalog(ResourceRecordEntity resource);

    /**
     * 从 context_catalog 中软移除 Resource 对应的节点。
     *
     * <p>当 Resource 被软删除时调用。
     *
     * @param resource 已删除的 Resource 实体
     */
    void removeFromCatalog(ResourceRecordEntity resource);
}
