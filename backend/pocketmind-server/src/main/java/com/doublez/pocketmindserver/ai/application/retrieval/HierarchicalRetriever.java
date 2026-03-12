package com.doublez.pocketmindserver.ai.application.retrieval;

/**
 * 层级检索器 — 对外唯一入口。
 *
 * <p>对齐 OpenViking {@code HierarchicalRetriever.retrieve()}，
 * 实现基于优先队列的递归搜索 + 得分传播 + 收敛检测。
 *
 * <p>接口保持稳定，实现可自由切换：
 * <ul>
 *   <li>{@link DefaultHierarchicalRetriever} — DB + SQL 关键词匹配</li>
 *   <li>未来：DB + pgvector 语义搜索</li>
 *   <li>未来：AGFS 文件系统 + 向量索引</li>
 * </ul>
 *
 * <p>所有实现必须保证<b>虚拟线程安全</b>。
 */
public interface HierarchicalRetriever {

    /**
     * 执行层级检索。
     *
     * @param query  检索查询规格
     * @param userId 当前用户 ID（空间隔离）
     * @return 检索结果（按 finalScore 降序排列的命中节点）
     */
    RetrievalResult retrieve(RetrievalQuery query, long userId);
}
