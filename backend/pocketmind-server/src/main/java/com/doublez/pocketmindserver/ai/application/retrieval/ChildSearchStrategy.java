package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;

import java.util.List;

/**
 * 子节点搜索策略 — 层级检索的 SPI 扩展点。
 *
 * <p>该接口将"如何发现子节点并打分"从递归算法中解耦，
 * 允许以下实现方式自由切换或组合：
 * <ul>
 *   <li>{@code DbChildSearchStrategy} — 基于 SQL 关键词匹配</li>
 *   <li>{@code VectorChildSearchStrategy} — 基于 pgvector 语义搜索（未来）</li>
 *   <li>{@code FileChildSearchStrategy} — 文件系统目录遍历（AGFS 场景）</li>
 *   <li>{@code CompositeChildSearchStrategy} — 多策略融合</li>
 * </ul>
 *
 * <p>所有实现必须保证<b>线程安全</b>（可在虚拟线程中并发调用）。
 */
public interface ChildSearchStrategy {

    /**
     * 搜索指定父节点下的子节点并打分。
     *
     * <p>返回的 {@link ScoredNode} 中的 score 是<b>原始查询相关性得分</b>，
     * 尚未经过 score propagation 或 hotness 融合。
     *
     * @param parentUri 父节点 URI
     * @param queryText 查询文本
     * @param userId    用户 ID（空间隔离）
     * @param limit     最大返回数量
     * @return 子节点得分列表（按 score 降序）
     */
    List<ScoredNode> searchChildren(ContextUri parentUri, String queryText, long userId, int limit);

    /**
     * 全局搜索 — 跨目录查找与查询最相关的起始点。
     *
     * <p>对齐 OpenViking 的 {@code search_global_roots_in_tenant}，
     * 用于在层级检索启动前补充全局高分起始节点。
     *
     * @param queryText   查询文本
     * @param userId      用户 ID
     * @param contextType 限定类型（null = 所有类型）
     * @param limit       最大返回数量
     * @return 全局高分节点列表
     */
    List<ScoredNode> globalSearch(String queryText, long userId, ContextType contextType, int limit);

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
}
