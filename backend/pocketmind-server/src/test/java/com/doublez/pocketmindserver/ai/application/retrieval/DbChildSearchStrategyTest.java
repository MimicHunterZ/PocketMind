package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextLayer;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * DbChildSearchStrategy 单测 — 使用内存 Repository 验证关键词打分逻辑。
 */
class DbChildSearchStrategyTest {

    private InMemoryCatalogRepository repository;
    private DbChildSearchStrategy strategy;

    @BeforeEach
    void setUp() {
        repository = new InMemoryCatalogRepository();
        strategy = new DbChildSearchStrategy(repository);
    }

    @Test
    void 完整匹配关键词得满分() {
        long userId = 1L;
        ContextUri root = ContextUri.userResourcesRoot(userId);
        ContextNode node = new ContextNode(
                root.child("note-1"), root, ContextType.RESOURCE, ContextLayer.L2_DETAIL,
                "Spring Boot 架构设计", "介绍 Spring Boot 的分层架构",
                0L, System.currentTimeMillis(), true);
        repository.addChildNode(root.value(), node);

        List<ScoredNode> results = strategy.searchChildren(root, "Spring Boot 架构设计", userId, 10);

        assertThat(results).hasSize(1);
        assertThat(results.get(0).score()).isEqualTo(1.0);
    }

    @Test
    void 部分关键词匹配得部分分() {
        long userId = 1L;
        ContextUri root = ContextUri.userResourcesRoot(userId);
        ContextNode node = new ContextNode(
                root.child("note-1"), root, ContextType.RESOURCE, ContextLayer.L2_DETAIL,
                "Spring Boot 架构设计", "分层架构",
                0L, System.currentTimeMillis(), true);
        repository.addChildNode(root.value(), node);

        // 查询 "Spring Flutter" — 只命中 "Spring"
        List<ScoredNode> results = strategy.searchChildren(root, "Spring Flutter", userId, 10);

        assertThat(results).hasSize(1);
        // 1/2 命中 → 0.3 + 0.7 * 0.5 = 0.65
        assertThat(results.get(0).score()).isCloseTo(0.65, org.assertj.core.data.Offset.offset(0.01));
    }

    @Test
    void 完全不匹配得零分() {
        long userId = 1L;
        ContextUri root = ContextUri.userResourcesRoot(userId);
        ContextNode node = new ContextNode(
                root.child("note-1"), root, ContextType.RESOURCE, ContextLayer.L2_DETAIL,
                "Rust 入门教程", "系统编程语言",
                0L, System.currentTimeMillis(), true);
        repository.addChildNode(root.value(), node);

        List<ScoredNode> results = strategy.searchChildren(root, "Python 机器学习", userId, 10);

        assertThat(results).hasSize(1);
        assertThat(results.get(0).score()).isEqualTo(0.0);
    }

    @Test
    void 全局搜索按关键词匹配() {
        long userId = 1L;
        ContextNode hit = new ContextNode(
                ContextUri.of("pm://users/1/resources/notes/spring"),
                ContextUri.userResourcesRoot(userId),
                ContextType.RESOURCE, ContextLayer.L2_DETAIL,
                "Spring AI 指南", "Spring AI 与大模型集成",
                5L, System.currentTimeMillis(), true);
        ContextNode miss = new ContextNode(
                ContextUri.of("pm://users/1/resources/notes/flutter"),
                ContextUri.userResourcesRoot(userId),
                ContextType.RESOURCE, ContextLayer.L2_DETAIL,
                "Flutter 状态管理", "Riverpod 使用指南",
                0L, System.currentTimeMillis(), true);
        repository.addSearchResult("Spring", hit);
        repository.addSearchResult("Spring", miss); // miss 但被搜索返回

        List<ScoredNode> results = strategy.globalSearch("Spring AI", userId, ContextType.RESOURCE, 5);

        assertThat(results).isNotEmpty();
        // Spring AI 指南应排在前面
        assertThat(results.get(0).node().name()).isEqualTo("Spring AI 指南");
    }

    @Test
    void 空父节点返回空列表() {
        List<ScoredNode> results = strategy.searchChildren(
                ContextUri.userResourcesRoot(99L), "任何", 99L, 10);
        assertThat(results).isEmpty();
    }

    // ─── 内存 Repository ─────────────────────────────────

    static class InMemoryCatalogRepository implements ContextCatalogRepository {

        private final Map<String, List<ContextNode>> childrenByParent = new ConcurrentHashMap<>();
        private final Map<String, List<ContextNode>> searchResults = new ConcurrentHashMap<>();

        void addChildNode(String parentUri, ContextNode node) {
            childrenByParent.computeIfAbsent(parentUri, k -> new ArrayList<>()).add(node);
        }

        void addSearchResult(String keyword, ContextNode node) {
            searchResults.computeIfAbsent(keyword, k -> new ArrayList<>()).add(node);
        }

        @Override
        public List<ContextNode> findChildrenByParentUri(String parentUri, long userId) {
            return childrenByParent.getOrDefault(parentUri, List.of());
        }

        @Override
        public List<ContextNode> findDescendantsByUriPrefix(String uriPrefix, long userId) {
            return List.of();
        }

        @Override
        public List<ContextNode> searchByKeyword(String keyword, Long userId,
                                                  ContextType contextType, int limit) {
            // 简单模拟：关键词包含则返回
            List<ContextNode> all = new ArrayList<>();
            for (var entry : searchResults.entrySet()) {
                if (keyword.toLowerCase().contains(entry.getKey().toLowerCase())) {
                    all.addAll(entry.getValue());
                }
            }
            return all.stream().limit(limit).toList();
        }

        @Override
        public Optional<ContextNode> findByUri(String uri) {
            return Optional.empty();
        }

        @Override
        public List<ContextNode> findByUris(List<String> uris) {
            return List.of();
        }

        @Override
        public void upsert(ContextNode node, Long userId) {
        }

        @Override
        public void incrementActiveCount(String uri) {
        }

        @Override
        public void incrementActiveCountBatch(List<String> uris) {
        }
    }
}
