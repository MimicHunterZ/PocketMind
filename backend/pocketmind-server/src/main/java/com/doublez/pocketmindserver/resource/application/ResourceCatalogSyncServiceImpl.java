package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.ai.application.embedding.EmbeddingService;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.UUID;
import java.util.Objects;
import java.util.Optional;

/**
 * 默认 Resource → ContextCatalog 同步实现。
 *
 * <p>同步策略：仅同步 Resource 对应的薄索引节点，不再创建目录树节点。
 */
@Slf4j
@Service
public class ResourceCatalogSyncServiceImpl implements ResourceCatalogSyncService {

    private final ContextCatalogRepository catalogRepository;
    private final EmbeddingService embeddingService;

    public ResourceCatalogSyncServiceImpl(ContextCatalogRepository catalogRepository,
                                          EmbeddingService embeddingService) {
        this.catalogRepository = catalogRepository;
        this.embeddingService = embeddingService;
    }

    @Override
    public void syncToCatalog(ResourceRecordEntity resource) {
        long userId = resource.getUserId();
        String resourceUri = resource.getRootUri().value();

        // upsert Resource 自身为薄索引节点
        String abstractText = resource.getAbstractText() != null
                ? resource.getAbstractText()
                : resource.deriveDefaultAbstract();
        Optional<ContextNode> existing = catalogRepository.findByUri(resourceUri);

        ContextNode leafNode = new ContextNode(
                resource.getRootUri(),
                resource.getUuid(),
                ContextType.RESOURCE,
                resource.getTitle() != null ? resource.getTitle() : "未命名资源",
                abstractText,
                existing.map(ContextNode::activeCount).orElse(0L),
                resource.getUpdatedAt()
        );

        catalogRepository.upsert(leafNode, userId);
        log.debug("[resource-catalog-sync] 同步资源索引节点: uri={}", resourceUri);

        // 为索引节点生成向量嵌入
        if (shouldEmbed(existing, abstractText)) {
            embedNode(resourceUri, abstractText);
        }
    }

    @Override
    public void removeFromCatalog(ResourceRecordEntity resource) {
        log.debug("[resource-catalog-sync] 资源已删除, 同步级联逻辑删除 context_catalog 条目: uri={}", resource.getRootUri().value());
        catalogRepository.deleteByResourceUuid(resource.getUuid());
    }

    @Override
    public void removeFromCatalogByResourceUuid(UUID resourceUuid) {
        catalogRepository.deleteByResourceUuid(resourceUuid);
    }

    /**
     * 为指定节点生成并存储向量嵌入。
     */
    private void embedNode(String uri, String text) {
        try {
            float[] embedding = embeddingService.embed(text);
            if (embedding != null) {
                catalogRepository.updateEmbedding(uri, embedding);
            }
        } catch (Exception e) {
            log.warn("[resource-catalog-sync] 向量嵌入失败, 不影响同步: uri={}, error={}", uri, e.getMessage());
        }
    }

    private boolean shouldEmbed(Optional<ContextNode> existing, String abstractText) {
        return existing.isEmpty() || !Objects.equals(existing.get().abstractText(), abstractText);
    }
}
