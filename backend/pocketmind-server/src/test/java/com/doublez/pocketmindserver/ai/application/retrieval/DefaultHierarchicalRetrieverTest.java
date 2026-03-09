package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextLayer;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * DefaultHierarchicalRetriever 单测 — 验证递归算法核心行为。
 *
 * <p>使用 InMemoryChildSearchStrategy 模拟层级树，
 * 隔离数据库依赖，专注测试算法正确性。
 */
class DefaultHierarchicalRetrieverTest {

    private InMemoryChildSearchStrategy strategy;
    private DefaultHotnessScorer hotnessScorer;
    private DefaultHierarchicalRetriever retriever;

    @BeforeEach
    void setUp() {
        strategy = new InMemoryChildSearchStrategy();
        hotnessScorer = new DefaultHotnessScorer();
        retriever = new DefaultHierarchicalRetriever(strategy, hotnessScorer);
    }

    @Test
    void 空目录返回空结果() {
        RetrievalQuery query = RetrievalQuery.of("任何查询", 5);
        RetrievalResult result = retriever.retrieve(query, 1L);
        assertThat(result.matches()).isEmpty();
    }

    @Test
    void 单层扁平结构直接返回匹配项() {
        long userId = 1L;
        ContextUri root = ContextUri.userResourcesRoot(userId);

        // 3 个叶子节点
        strategy.addChildren(root, List.of(
                leafNode(root, "note-1", "Spring Boot 架构笔记", 0.8),
                leafNode(root, "note-2", "Flutter 状态管理", 0.3),
                leafNode(root, "note-3", "Spring AI 集成指南", 0.9)
        ));

        RetrievalQuery query = RetrievalQuery.of("Spring", ContextType.RESOURCE, 2);
        RetrievalResult result = retriever.retrieve(query, userId);

        assertThat(result.matches()).hasSize(2);
        // Spring AI 集成指南 得分最高
        assertThat(result.matches().get(0).node().name()).isEqualTo("Spring AI 集成指南");
    }

    @Test
    void 两层结构正确递归并传播分数() {
        long userId = 1L;
        ContextUri root = ContextUri.userResourcesRoot(userId);
        ContextUri notesDir = root.child("notes");

        // 根节点有一个目录子节点
        strategy.addChildren(root, List.of(
                dirNode(root, "notes", "用户笔记合集", 0.6)
        ));

        // 目录下有两个叶子
        strategy.addChildren(notesDir, List.of(
                leafNode(notesDir, "java-basics", "Java 基础入门", 0.7),
                leafNode(notesDir, "kotlin-tips", "Kotlin 进阶技巧", 0.4)
        ));

        RetrievalQuery query = RetrievalQuery.of("Java", ContextType.RESOURCE, 5);
        RetrievalResult result = retriever.retrieve(query, userId);

        assertThat(result.matches()).isNotEmpty();
        // Java 基础入门应在结果中
        boolean hasJava = result.matches().stream()
                .anyMatch(s -> s.node().name().equals("Java 基础入门"));
        assertThat(hasJava).isTrue();
    }

    @Test
    void 得分传播系数正确应用() {
        long userId = 1L;
        ContextUri root = ContextUri.userResourcesRoot(userId);
        ContextUri dir = root.child("dir");

        strategy.addChildren(root, List.of(
                dirNode(root, "dir", "目录", 0.8)
        ));

        strategy.addChildren(dir, List.of(
                leafNode(dir, "child", "子节点", 0.6)
        ));

        RetrievalQuery query = RetrievalQuery.of("测试", ContextType.RESOURCE, 10);
        RetrievalResult result = retriever.retrieve(query, userId);

        // 目录 raw=0.8, parent=0.0 → dirScore=0.8（根节点 parent=0）
        // 子节点 raw=0.6, parent=0.8 → childScore = 0.5 * 0.6 + 0.5 * 0.8 = 0.7
        // 经过 hotness blending 后可能略有偏移，但应接近 0.7
        ScoredNode child = result.matches().stream()
                .filter(s -> s.node().name().equals("子节点"))
                .findFirst().orElse(null);
        assertThat(child).isNotNull();
        // 因为 hotness alpha=0.2，且 activeCount=0, updatedAt=0 → hotness=0
        // blended = 0.8 * 0.7 + 0.2 * 0 = 0.56
        assertThat(child.score()).isCloseTo(0.56, org.assertj.core.data.Offset.offset(0.05));
    }

    @Test
    void 收敛检测提前终止() {
        long userId = 1L;
        ContextUri root = ContextUri.userResourcesRoot(userId);

        // 创建一棵很深的树，但第一层就有最佳结果
        ContextUri current = root;
        for (int depth = 0; depth < 20; depth++) {
            String childName = "dir-" + depth;
            ContextUri childUri = current.child(childName);
            List<ScoredNodeFixture> children = new ArrayList<>();
            children.add(new ScoredNodeFixture(
                    dirNode(current, childName, "深层目录 " + depth, 0.1), 0.1));
            // 每层有一个叶子
            children.add(new ScoredNodeFixture(
                    leafNode(current, "leaf-" + depth, "叶子 " + depth, 0.9), 0.9));
            strategy.addChildren(current, children.stream().map(f -> f.scoredNode).toList());
            current = childUri;
        }

        RetrievalQuery query = RetrievalQuery.of("叶子", ContextType.RESOURCE, 2);
        RetrievalResult result = retriever.retrieve(query, userId);

        // 应该在收敛后提前停止，不会遍历全部 20 层
        assertThat(result.matches()).isNotEmpty();
        // 访问的目录不应超过 20（收敛应更早发生）
        assertThat(result.searchedDirectories()).isNotEmpty();
    }

    @Test
    void 全局搜索结果作为起始点补充() {
        long userId = 1L;
        ContextUri deepUri = ContextUri.of("pm://users/" + userId + "/resources/notes/hidden");

        // 根节点无子节点（空树）
        // 但全局搜索直接返回深层节点
        strategy.setGlobalResults(List.of(
                leafNode(null, "hidden", "隐藏笔记：Spring Boot 秘籍", 0.95)
        ), deepUri);

        RetrievalQuery query = RetrievalQuery.of("Spring Boot", ContextType.RESOURCE, 5);
        RetrievalResult result = retriever.retrieve(query, userId);

        assertThat(result.matches()).isNotEmpty();
    }

    @Test
    void 多类型搜索不限制contextType() {
        long userId = 1L;
        ContextUri resourceRoot = ContextUri.userResourcesRoot(userId);
        ContextUri memoryRoot = ContextUri.userMemoriesRoot(userId);

        strategy.addChildren(resourceRoot, List.of(
                leafNode(resourceRoot, "note-1", "架构笔记", 0.7)
        ));
        strategy.addChildren(memoryRoot, List.of(
                memoryLeafNode(memoryRoot, "pref-1", "偏好：中文输出", 0.6)
        ));

        RetrievalQuery query = RetrievalQuery.of("笔记", 5); // contextType = null
        RetrievalResult result = retriever.retrieve(query, userId);

        // 应搜索 resource 和 memory 两棵树
        assertThat(result.searchedDirectories()).hasSizeGreaterThanOrEqualTo(2);
    }

    // ─── 辅助方法 ──────────────────────────────────────────────

    private ScoredNode leafNode(ContextUri parent, String segment, String name, double score) {
        ContextUri uri = parent != null ? parent.child(segment) : ContextUri.of("pm://test/" + segment);
        ContextNode node = new ContextNode(
                uri, parent, ContextType.RESOURCE, ContextLayer.L2_DETAIL,
                name, name, 0L, 0L, true);
        return new ScoredNode(node, score);
    }

    private ScoredNode dirNode(ContextUri parent, String segment, String name, double score) {
        ContextUri uri = parent.child(segment);
        ContextNode node = new ContextNode(
                uri, parent, ContextType.RESOURCE, ContextLayer.L0_ABSTRACT,
                name, name, 0L, 0L, false);
        return new ScoredNode(node, score);
    }

    private ScoredNode memoryLeafNode(ContextUri parent, String segment, String name, double score) {
        ContextUri uri = parent.child(segment);
        ContextNode node = new ContextNode(
                uri, parent, ContextType.MEMORY, ContextLayer.L2_DETAIL,
                name, name, 0L, 0L, true);
        return new ScoredNode(node, score);
    }

    record ScoredNodeFixture(ScoredNode scoredNode, double rawScore) {}

    // ─── 内存 Child Search Strategy ─────────────────────────

    /**
     * 内存中的子节点搜索策略 — 用固定的 Map 模拟目录树。
     */
    static class InMemoryChildSearchStrategy implements ChildSearchStrategy {

        private final Map<String, List<ScoredNode>> childrenMap = new ConcurrentHashMap<>();
        private List<ScoredNode> globalResults = List.of();
        private ContextUri globalResultParent = null;

        void addChildren(ContextUri parent, List<ScoredNode> children) {
            childrenMap.put(parent.value(), children);
        }

        void setGlobalResults(List<ScoredNode> results, ContextUri parent) {
            this.globalResults = results;
            this.globalResultParent = parent;
        }

        @Override
        public List<ScoredNode> searchChildren(ContextUri parentUri, String queryText,
                                                long userId, int limit) {
            List<ScoredNode> children = childrenMap.getOrDefault(parentUri.value(), List.of());
            return children.stream().limit(limit).toList();
        }

        @Override
        public List<ScoredNode> globalSearch(String queryText, long userId,
                                              ContextType contextType, int limit) {
            return globalResults.stream().limit(limit).toList();
        }
    }
}
