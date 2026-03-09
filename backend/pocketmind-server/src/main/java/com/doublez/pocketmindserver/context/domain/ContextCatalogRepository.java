package com.doublez.pocketmindserver.context.domain;

import java.util.List;
import java.util.Optional;

/**
 * 上下文目录仓库接口 — 对应 context_catalog 表。
 *
 * <p>context_catalog 是层级检索树的元数据索引表，
 * 每行代表 URI 树中的一个节点（目录或叶子）。
 */
public interface ContextCatalogRepository {

    /**
     * 按 parent_uri 查找子节点（一级直接子节点）。
     */
    List<ContextNode> findChildrenByParentUri(String parentUri, long userId);

    /**
     * 按 parent_uri 前缀匹配查找所有后代节点。
     *
     * <p>用于全文搜索场景下快速获取某棵子树的所有节点。
     */
    List<ContextNode> findDescendantsByUriPrefix(String uriPrefix, long userId);

    /**
     * 全局关键词搜索 — 在 name 和 description 字段上进行模糊匹配。
     *
     * @param keyword     搜索关键词
     * @param userId      用户 ID
     * @param contextType 上下文类型（null = 搜索所有类型）
     * @param limit       最大返回数量
     * @return 匹配的节点列表
     */
    List<ContextNode> searchByKeyword(String keyword, Long userId, ContextType contextType, int limit);

    /**
     * 按 URI 精确查找节点。
     */
    Optional<ContextNode> findByUri(String uri);

    /**
     * 批量按 URI 查找节点。
     */
    List<ContextNode> findByUris(List<String> uris);

    /**
     * 保存或更新节点。
     *
     * <p>若 URI 已存在则更新（upsert 语义），否则插入新行。
     */
    void upsert(ContextNode node, Long userId);

    /**
     * 递增节点的 active_count。
     */
    void incrementActiveCount(String uri);

    /**
     * 批量递增 active_count。
     */
    void incrementActiveCountBatch(List<String> uris);
}
