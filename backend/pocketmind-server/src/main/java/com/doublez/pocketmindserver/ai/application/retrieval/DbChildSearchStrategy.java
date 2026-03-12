package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/**
 * 基于数据库关键词匹配的子节点搜索策略。
 *
 * <h3>工作方式</h3>
 * <ol>
 *   <li>按 parent_uri 查找直接子节点（context_catalog 的 parent_uri 索引）</li>
 *   <li>对每个子节点的 name + description 进行关键词匹配打分</li>
 *   <li>无法匹配的子节点仍返回（得 0 分），保证树遍历完整性</li>
 * </ol>
 *
 * <h3>打分策略</h3>
 * <ul>
 *   <li>精确匹配（name 完全包含查询） → 1.0</li>
 *   <li>关键词匹配（分词后至少一个命中） → 0.3 + 0.7 × (命中数 / 总词数)</li>
 *   <li>无匹配 → 0.0</li>
 * </ul>
 */
@Slf4j
@Component
public class DbChildSearchStrategy implements ChildSearchStrategy {

    private final ContextCatalogRepository catalogRepository;

    public DbChildSearchStrategy(ContextCatalogRepository catalogRepository) {
        this.catalogRepository = catalogRepository;
    }

    @Override
    public List<ScoredNode> searchChildren(ContextUri parentUri, String queryText, long userId, int limit) {
        List<ContextNode> children = catalogRepository.findChildrenByParentUri(parentUri.value(), userId);

        if (children.isEmpty()) {
            return List.of();
        }

        String[] queryTokens = tokenize(queryText);
        List<ScoredNode> scored = new ArrayList<>(children.size());

        for (ContextNode child : children) {
            double score = computeRelevanceScore(child, queryTokens);
            scored.add(new ScoredNode(child, score));
        }

        // 按分数降序，截取 limit
        scored.sort(null); // ScoredNode implements Comparable（降序）
        if (scored.size() > limit) {
            scored = new ArrayList<>(scored.subList(0, limit));
        }

        return scored;
    }

    @Override
    public List<ScoredNode> globalSearch(String queryText, long userId, ContextType contextType, int limit) {
        List<ContextNode> hits = catalogRepository.searchByKeyword(queryText, userId, contextType, limit);

        String[] queryTokens = tokenize(queryText);
        return hits.stream()
                .map(node -> new ScoredNode(node, computeRelevanceScore(node, queryTokens)))
                .sorted()
                .limit(limit)
                .toList();
    }

    @Override
    public List<ScoredNode> loadByUris(List<ContextUri> uris, long userId) {
        List<String> uriValues = uris.stream().map(ContextUri::value).toList();
        List<ContextNode> nodes = catalogRepository.findByUris(uriValues);
        return nodes.stream()
                .map(node -> new ScoredNode(node, 0.0))
                .toList();
    }

    // ─── 关键词打分 ──────────────────────────────────────────────

    /**
     * 计算查询与节点的关键词相关性得分 [0.0, 1.0]。
     */
    private double computeRelevanceScore(ContextNode node, String[] queryTokens) {
        if (queryTokens.length == 0) {
            return 0.0;
        }

        String searchableText = buildSearchableText(node);
        if (searchableText.isEmpty()) {
            return 0.0;
        }

        String lowerText = searchableText.toLowerCase();

        // 完整查询匹配 → 满分
        String fullQuery = String.join(" ", queryTokens).toLowerCase();
        if (lowerText.contains(fullQuery)) {
            return 1.0;
        }

        // 分词匹配 → 部分分
        int matchCount = 0;
        for (String token : queryTokens) {
            if (lowerText.contains(token.toLowerCase())) {
                matchCount++;
            }
        }

        if (matchCount == 0) {
            return 0.0;
        }

        return 0.3 + 0.7 * ((double) matchCount / queryTokens.length);
    }

    /**
     * 构建可搜索文本：name + abstractText / description。
     */
    private String buildSearchableText(ContextNode node) {
        StringBuilder sb = new StringBuilder();
        if (node.name() != null) {
            sb.append(node.name());
        }
        if (node.abstractText() != null) {
            if (!sb.isEmpty()) {
                sb.append(' ');
            }
            sb.append(node.abstractText());
        }
        return sb.toString();
    }

    /**
     * 简单分词 — 按空白/标点切分。
     */
    private String[] tokenize(String text) {
        if (text == null || text.isBlank()) {
            return new String[0];
        }
        return text.trim().split("[\\s,\uFF0C\u3002\uFF01\uFF1F\u3001\uFF1B\uFF1A\u201C\u201D\u2018\u2019\uFF08\uFF09()\\[\\]\u3010\u3011]+");
    }
}
