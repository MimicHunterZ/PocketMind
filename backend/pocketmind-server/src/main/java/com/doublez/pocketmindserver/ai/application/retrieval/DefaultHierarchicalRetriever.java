package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextLayer;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.PriorityQueue;
import java.util.Set;

/**
 * 默认层级检索器 — OpenViking 递归算法的 Java 实现。
 *
 * <h3>核心算法（对齐 OpenViking HierarchicalRetriever._recursive_search）</h3>
 * <pre>
 * 1. 初始化 = 根节点（按 contextType 推导）+ 全局搜索 top-3 → 合并为起始点
 * 2. 优先队列循环：
 *    a. 弹出得分最高的目录节点
 *    b. 搜索其子节点（委托 ChildSearchStrategy）
 *    c. 得分传播：finalScore = α × childRawScore + (1 - α) × parentScore
 *    d. L0/L1 非叶子节点 → 加入队列继续递归
 *    e. L2 / 叶子节点 → 收集为最终候选
 *    f. 收敛检测：连续 3 轮 top-k 集合不变 → 提前终止
 * 3. 对候选进行 hotness 融合后按 finalScore 降序返回 top-limit
 * </pre>
 *
 * <h3>扩展性设计</h3>
 * <ul>
 *   <li>搜索后端通过 {@link ChildSearchStrategy} SPI 注入 — 切换 DB/向量/文件不改递归逻辑</li>
 *   <li>热度评分通过 {@link HotnessScorer} SPI 注入 — 可独立调参</li>
 *   <li>所有常量可配置化（当前使用与 OpenViking 一致的默认值）</li>
 * </ul>
 *
 * <h3>虚拟线程安全</h3>
 * 所有状态均为方法局部变量，无实例可变状态，可安全在虚拟线程中并发调用。
 */
@Slf4j
@Component
public class DefaultHierarchicalRetriever implements HierarchicalRetriever {

    // ─── 对齐 OpenViking 常量 ─────────────────────────────────────

    /** 得分传播系数。childFinal = α × childRaw + (1 - α) × parentScore */
    static final double SCORE_PROPAGATION_ALPHA = 0.5;

    /** 热度融合权重。finalScore = (1 - α) × semanticScore + α × hotnessScore */
    static final double HOTNESS_ALPHA = 0.2;

    /** 全局搜索返回数量。 */
    static final int GLOBAL_SEARCH_TOPK = 3;

    /** 收敛检测：连续不变轮数阈值。 */
    static final int MAX_CONVERGENCE_ROUNDS = 3;

    /** 子节点搜索预取倍率：max(limit × PRE_FILTER_MULTIPLIER, PRE_FILTER_MIN)。 */
    private static final int PRE_FILTER_MULTIPLIER = 2;
    private static final int PRE_FILTER_MIN = 20;

    private final ChildSearchStrategy childSearchStrategy;
    private final HotnessScorer hotnessScorer;

    public DefaultHierarchicalRetriever(ChildSearchStrategy childSearchStrategy,
                                        HotnessScorer hotnessScorer) {
        this.childSearchStrategy = childSearchStrategy;
        this.hotnessScorer = hotnessScorer;
    }

    @Override
    public RetrievalResult retrieve(RetrievalQuery query, long userId) {
        // Step 1：确定起始目录
        List<ContextUri> rootUris = resolveRootUris(query, userId);

        // Step 2：全局搜索补充起始点
        List<ScoredNode> globalHits = childSearchStrategy.globalSearch(
                query.queryText(), userId, query.contextType(), GLOBAL_SEARCH_TOPK);

        // Step 3：合并起始点（全局命中的终端节点直接作为候选）
        List<ScoredNode> preCollected = new ArrayList<>();
        List<StartingPoint> startingPoints = mergeStartingPoints(rootUris, globalHits, preCollected, userId);

        if (startingPoints.isEmpty() && preCollected.isEmpty()) {
            log.debug("[retrieval] 无起始点, userId={}, query={}", userId, query.queryText());
            return RetrievalResult.empty(query);
        }

        // Step 4：递归搜索
        List<ScoredNode> candidates = recursiveSearch(
                query.queryText(), userId, startingPoints, preCollected, query.limit(), query.contextType());

        // Step 5：Hotness 融合与最终排序
        List<ScoredNode> blended = applyHotnessBlending(candidates);

        // Step 6：截取 top-limit
        List<ScoredNode> finalResults = blended.stream()
                .limit(query.limit())
                .toList();

        List<ContextUri> searched = new ArrayList<>(rootUris);
        globalHits.stream().map(s -> s.node().uri()).forEach(searched::add);

        return new RetrievalResult(query, finalResults, searched);
    }

    // ─── 内部方法 ─────────────────────────────────────────────────

    /**
     * 按 contextType 推导根节点 URI 列表。
     *
     * <p>若查询指定了 targetDirectories，直接使用；
     * 否则按 contextType 生成标准根路径。
     */
    private List<ContextUri> resolveRootUris(RetrievalQuery query, long userId) {
        if (!query.targetDirectories().isEmpty()) {
            return query.targetDirectories();
        }

        List<ContextUri> roots = new ArrayList<>();
        ContextType type = query.contextType();

        if (type == null || type == ContextType.RESOURCE) {
            roots.add(ContextUri.userResourcesRoot(userId));
        }
        if (type == null || type == ContextType.MEMORY) {
            roots.add(ContextUri.userMemoriesRoot(userId));
        }
        // SKILL 和 SESSION 留给后续阶段，暂不加入自动根节点

        return roots;
    }

    /**
     * 合并显式根节点与全局搜索结果为统一起始点列表。
     *
     * <p>全局搜索命中的终端节点（L2/叶子）直接放入 preCollected 候选池，
     * 非终端节点和显式根节点放入起始点队列。
     */
    private List<StartingPoint> mergeStartingPoints(List<ContextUri> rootUris,
                                                    List<ScoredNode> globalHits,
                                                    List<ScoredNode> preCollected,
                                                    long userId) {
        Map<String, StartingPoint> seen = new HashMap<>();

        // 全局搜索结果（带分数）：终端节点直接收为候选，目录节点加入队列
        for (ScoredNode hit : globalHits) {
            String key = hit.node().uri().value();
            if (hit.node().isTerminal()) {
                preCollected.add(hit);
            } else {
                seen.put(key, new StartingPoint(hit.node().uri(), hit.score()));
            }
        }

        // 显式根节点（0 分起始，但保证被访问）
        for (ContextUri uri : rootUris) {
            seen.putIfAbsent(uri.value(), new StartingPoint(uri, 0.0));
        }

        return new ArrayList<>(seen.values());
    }

    /**
     * 递归搜索核心 — 优先队列 + 得分传播 + 收敛检测。
     */
    private List<ScoredNode> recursiveSearch(String queryText,
                                              long userId,
                                              List<StartingPoint> startingPoints,
                                              List<ScoredNode> preCollected,
                                              int limit,
                                              ContextType contextType) {
        // 候选池：URI → 最高分 ScoredNode（先注入全局搜索的终端命中）
        Map<String, ScoredNode> collectedByUri = new HashMap<>();
        for (ScoredNode pre : preCollected) {
            collectedByUri.put(pre.node().uri().value(), pre);
        }

        // 最大堆：(-score, uri) — Java PQ 是最小堆，用负分模拟最大堆
        PriorityQueue<StartingPoint> dirQueue = new PriorityQueue<>(
                Comparator.comparingDouble(StartingPoint::score).reversed());

        Set<String> visited = new HashSet<>();
        Set<String> prevTopkUris = new HashSet<>();
        int convergenceRounds = 0;

        double alpha = SCORE_PROPAGATION_ALPHA;
        int preFilterLimit = Math.max(limit * PRE_FILTER_MULTIPLIER, PRE_FILTER_MIN);

        // 初始化队列
        for (StartingPoint sp : startingPoints) {
            dirQueue.offer(sp);
        }

        while (!dirQueue.isEmpty()) {
            StartingPoint current = dirQueue.poll();
            String currentUriValue = current.uri().value();
            double parentScore = current.score();

            if (visited.contains(currentUriValue)) {
                continue;
            }
            visited.add(currentUriValue);

            log.debug("[retrieval] 进入 URI: {}, parentScore={}", currentUriValue, parentScore);

            // 搜索子节点
            List<ScoredNode> children = childSearchStrategy.searchChildren(
                    current.uri(), queryText, userId, preFilterLimit);

            if (children.isEmpty()) {
                continue;
            }

            for (ScoredNode child : children) {
                ContextNode node = child.node();
                String childUriValue = node.uri().value();

                // 得分传播
                double rawScore = child.score();
                double finalScore = parentScore > 0
                        ? alpha * rawScore + (1 - alpha) * parentScore
                        : rawScore;

                // 去重：保留高分
                ScoredNode previous = collectedByUri.get(childUriValue);
                if (previous == null || finalScore > previous.score()) {
                    ScoredNode propagated = child.withScore(finalScore);
                    collectedByUri.put(childUriValue, propagated);
                }

                // 非终端节点（L0/L1 目录）→ 继续递归
                if (!node.isTerminal() && !visited.contains(childUriValue)) {
                    dirQueue.offer(new StartingPoint(node.uri(), finalScore));
                }
            }

            // 收敛检测
            Set<String> currentTopkUris = topKUris(collectedByUri, limit);
            if (currentTopkUris.equals(prevTopkUris) && currentTopkUris.size() >= limit) {
                convergenceRounds++;
                if (convergenceRounds >= MAX_CONVERGENCE_ROUNDS) {
                    log.debug("[retrieval] 收敛提前终止, rounds={}", convergenceRounds);
                    break;
                }
            } else {
                convergenceRounds = 0;
                prevTopkUris = currentTopkUris;
            }
        }

        // 按 finalScore 降序排列
        return collectedByUri.values().stream()
                .sorted(Comparator.comparingDouble(ScoredNode::score).reversed())
                .limit(limit)
                .toList();
    }

    /**
     * Hotness 融合 — 语义分 × (1 - α) + 热度分 × α。
     */
    private List<ScoredNode> applyHotnessBlending(List<ScoredNode> candidates) {
        if (HOTNESS_ALPHA <= 0.0) {
            return candidates;
        }

        return candidates.stream()
                .map(scored -> {
                    ContextNode node = scored.node();
                    double semanticScore = scored.score();
                    double hotness = hotnessScorer.score(node.activeCount(), node.updatedAt());
                    double blended = (1 - HOTNESS_ALPHA) * semanticScore + HOTNESS_ALPHA * hotness;
                    return scored.withScore(blended);
                })
                .sorted(Comparator.comparingDouble(ScoredNode::score).reversed())
                .toList();
    }

    /**
     * 取得分最高的 K 个 URI 集合。
     */
    private Set<String> topKUris(Map<String, ScoredNode> collectedByUri, int k) {
        return collectedByUri.values().stream()
                .sorted(Comparator.comparingDouble(ScoredNode::score).reversed())
                .limit(k)
                .map(s -> s.node().uri().value())
                .collect(HashSet::new, HashSet::add, HashSet::addAll);
    }

    /**
     * 起始点内部记录。
     */
    record StartingPoint(ContextUri uri, double score) {}
}
