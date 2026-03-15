package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.ai.application.embedding.EmbeddingService;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextLayer;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ResourceCatalogSyncService 单元测试 — 验证 Resource → ContextCatalog 目录同步。
 */
class ResourceCatalogSyncServiceTest {

    private InMemoryCatalogRepository catalogRepository;
    private ResourceCatalogSyncService syncService;

    @BeforeEach
    void setUp() {
        catalogRepository = new InMemoryCatalogRepository();
        syncService = new ResourceCatalogSyncServiceImpl(catalogRepository, new NoOpEmbeddingService());
    }

    @Test
    void 同步笔记资源应创建完整目录结构() {
        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(), 1L, UUID.randomUUID(),
                ContextUri.userResourcesRoot(1L).child("notes").child("test-note"),
                "架构笔记", "Spring Boot 4 重构记录");

        syncService.syncToCatalog(resource);

        // 应创建 3 个节点：根目录、notes 分组目录、资源叶子
        assertEquals(3, catalogRepository.storage.size());

        // 验证根目录
        Optional<ContextNode> root = catalogRepository.findByUri("pm://users/1/resources");
        assertTrue(root.isPresent());
        assertFalse(root.get().isLeaf());
        assertEquals(ContextLayer.L0_ABSTRACT, root.get().layer());

        // 验证 notes 分组目录
        Optional<ContextNode> notesDir = catalogRepository.findByUri("pm://users/1/resources/notes");
        assertTrue(notesDir.isPresent());
        assertFalse(notesDir.get().isLeaf());
        assertEquals("notes", notesDir.get().name());

        // 验证叶子节点
        Optional<ContextNode> leaf = catalogRepository.findByUri(resource.getRootUri().value());
        assertTrue(leaf.isPresent());
        assertTrue(leaf.get().isLeaf());
        assertEquals(ContextLayer.L2_DETAIL, leaf.get().layer());
        assertEquals("架构笔记", leaf.get().name());
    }

    @Test
    void 同步聊天记录应放入chats分组() {
        UUID sessionUuid = UUID.randomUUID();
        ResourceRecordEntity resource = ResourceRecordEntity.createChatTranscript(
                UUID.randomUUID(), 2L, sessionUuid,
                ContextUri.userResourcesRoot(2L).child("chats").child(sessionUuid.toString()),
                "聊天归档", "用户: 你好\n助手: 你好");

        syncService.syncToCatalog(resource);

        Optional<ContextNode> chatsDir = catalogRepository.findByUri("pm://users/2/resources/chats");
        assertTrue(chatsDir.isPresent());
        assertEquals("chats", chatsDir.get().name());
        assertTrue(chatsDir.get().abstractText().contains("对话"));
    }

    @Test
    void 同步OCR资源应放入assets分组() {
        UUID assetUuid = UUID.randomUUID();
        ResourceRecordEntity resource = ResourceRecordEntity.createAssetText(
                UUID.randomUUID(), 3L, assetUuid,
                ContextUri.userResourcesRoot(3L).child("assets").child(assetUuid.toString()),
                "OCR识别", "识别出的文本内容");

        syncService.syncToCatalog(resource);

        Optional<ContextNode> assetsDir = catalogRepository.findByUri("pm://users/3/resources/assets");
        assertTrue(assetsDir.isPresent());
        assertEquals("assets", assetsDir.get().name());
    }

    @Test
    void 重复同步相同资源应幂等() {
        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(), 1L, UUID.randomUUID(),
                ContextUri.userResourcesRoot(1L).child("notes").child("dup-note"),
                "笔记", "内容");

        syncService.syncToCatalog(resource);
        int sizeAfterFirst = catalogRepository.storage.size();

        // 第二次同步不应增加新节点（目录 upsert + 叶子 upsert）
        syncService.syncToCatalog(resource);
        assertEquals(sizeAfterFirst, catalogRepository.storage.size());
    }

    @Test
    void 叶子节点使用abstractText或deriveDefaultAbstract() {
        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(), 1L, UUID.randomUUID(),
                ContextUri.userResourcesRoot(1L).child("notes").child("abstract-test"),
                "笔记标题", "笔记正文");

        // 未设置 abstractText → 使用 deriveDefaultAbstract()
        syncService.syncToCatalog(resource);
        ContextNode leaf = catalogRepository.findByUri(resource.getRootUri().value()).orElseThrow();
        assertEquals("笔记标题：笔记正文", leaf.abstractText());

        // 设置 abstractText 后重新同步
        resource.updateAbstractText("AI 生成的精确摘要");
        syncService.syncToCatalog(resource);
        ContextNode updatedLeaf = catalogRepository.findByUri(resource.getRootUri().value()).orElseThrow();
        assertEquals("AI 生成的精确摘要", updatedLeaf.abstractText());
    }

    @Test
    void 无标题资源使用默认名称() {
        ResourceRecordEntity resource = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(), 1L, UUID.randomUUID(),
                ContextUri.userResourcesRoot(1L).child("notes").child("untitled"),
                null, "有正文但无标题");

        syncService.syncToCatalog(resource);

        ContextNode leaf = catalogRepository.findByUri(resource.getRootUri().value()).orElseThrow();
        assertEquals("未命名资源", leaf.name());
    }

    // ─── 内存仓库 ─────────────────────────────────────────────────

    /**
     * 内存 ContextCatalogRepository — 模拟 DB，隔离持久化依赖。
     */
    private static class InMemoryCatalogRepository implements ContextCatalogRepository {

        final List<ContextNode> storage = new ArrayList<>();

        @Override
        public List<ContextNode> findChildrenByParentUri(String parentUri, long userId) {
            return storage.stream()
                    .filter(n -> n.parentUri() != null && n.parentUri().value().equals(parentUri))
                    .toList();
        }

        @Override
        public List<ContextNode> findDescendantsByUriPrefix(String uriPrefix, long userId) {
            return storage.stream()
                    .filter(n -> n.uri().value().startsWith(uriPrefix))
                    .toList();
        }

        @Override
        public List<ContextNode> searchByKeyword(String keyword, Long userId, ContextType contextType, int limit) {
            return storage.stream()
                    .filter(n -> (n.name() != null && n.name().contains(keyword))
                            || (n.abstractText() != null && n.abstractText().contains(keyword)))
                    .limit(limit)
                    .toList();
        }

        @Override
        public Optional<ContextNode> findByUri(String uri) {
            return storage.stream()
                    .filter(n -> n.uri().value().equals(uri))
                    .findFirst();
        }

        @Override
        public List<ContextNode> findByUris(List<String> uris) {
            return storage.stream()
                    .filter(n -> uris.contains(n.uri().value()))
                    .toList();
        }

        @Override
        public void upsert(ContextNode node, Long userId) {
            storage.removeIf(n -> n.uri().value().equals(node.uri().value()));
            storage.add(node);
        }

        @Override
        public void incrementActiveCount(String uri) {
        }

        @Override
        public void incrementActiveCountBatch(List<String> uris) {
        }

        @Override
        public List<ScoredCatalogEntry> searchByVector(float[] queryVector, long userId, ContextType contextType, int limit) {
            return List.of();
        }

        @Override
        public List<ScoredCatalogEntry> searchChildrenByVector(float[] queryVector, String parentUri, long userId, int limit) {
            return List.of();
        }

        @Override
        public void updateEmbedding(String uri, float[] embedding) {
        }

        @Override
        public void deleteByUri(String uri) {
            storage.removeIf(n -> n.uri().value().equals(uri));
        }
    }

    /**
     * 无操作的 EmbeddingService — 测试中不实际调用向量嵌入。
     */
    private static class NoOpEmbeddingService extends EmbeddingService {
        NoOpEmbeddingService() {
            super(null);
        }

        @Override
        public float[] embed(String text) {
            return null;
        }
    }
}
