package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;

import java.util.List;

/**
 * 索引搜索策略 SPI。
 *
 * <p>该接口将"如何检索索引节点并打分"从上层编排中解耦，
 * 允许实现方式自由切换或组合：
 * <ul>
 *   <li>{@code VectorChildSearchStrategy} — 基于 pgvector 语义搜索</li>
 *   <li>{@code FileChildSearchStrategy} — 文件系统目录遍历（AGFS 场景）</li>
 *   <li>{@code CompositeChildSearchStrategy} — 多策略融合</li>
 * </ul>
 *
 * <p>所有实现必须保证<b>线程安全</b>（可在虚拟线程中并发调用）。
 */
public interface ChildSearchStrategy {

    /**
 * 平铺搜索相关节点并打分。
     *
     * <p>返回的 {@link ScoredNode} 中的 score 是<b>原始查询相关性得分</b>，
     * 尚未经过 score propagation 或 hotness 融合。
     *
     * @param queryText 查询文本
     * @param userId    用户 ID（空间隔离）
     * @param limit     最大返回数量
     * @return 命中节点得分列表（按 score 降序）
     */
    List<ScoredNode> search(String queryText, long userId, ContextType contextType, int limit);

    /**
     * 按 URI 列表批量加载节点摘要（L0 层级内容）。
     *
     * <p>用于对起始目录进行初始化打分。默认实现返回 0 分节点。
     *
     * @param uris   待加载的 URI 列表
     * @param userId 用户 ID
     * @return 节点列表（可能不完整，忽略不存在的 URI）
     */
    default List<ScoredNode> loadByUris(List<ContextUri> uris, long userId) {
        return List.of();
    }

    /**
     * 兼容旧命名：委托到平铺搜索。
     */
    default List<ScoredNode> globalSearch(String queryText, long userId, ContextType contextType, int limit) {
        return search(queryText, userId, contextType, limit);
    }
}
