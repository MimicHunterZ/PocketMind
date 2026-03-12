package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.ai.application.embedding.EmbeddingService;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextLayer;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 默认 Resource → ContextCatalog 同步实现。
 *
 * <p>同步策略：
 * <ul>
 *   <li>Resource 自身 → L2_DETAIL 叶子节点</li>
 *   <li>来源分组目录（如 notes/、chats/） → L0_ABSTRACT 目录节点</li>
 *   <li>用户资源根目录 → L0_ABSTRACT 目录节点</li>
 * </ul>
 *
 * <p>目录节点采用 upsert 语义，已存在则跳过不覆盖描述。
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
        ContextUri resourceUri = resource.getRootUri();

        // 1. 确保用户资源根目录节点存在
        ContextUri rootUri = ContextUri.userResourcesRoot(userId);
        ensureDirectoryNode(rootUri, null, "resources", "用户资源根目录", userId);

        // 2. 确保来源分组目录节点存在（notes/ chats/ assets/）
        String groupSegment = resolveGroupSegment(resource.getSourceType());
        ContextUri groupUri = rootUri.child(groupSegment);
        String groupDescription = resolveGroupDescription(resource.getSourceType());
        ensureDirectoryNode(groupUri, rootUri, groupSegment, groupDescription, userId);

        // 3. upsert Resource 自身为叶子节点
        String abstractText = resource.getAbstractText() != null
                ? resource.getAbstractText()
                : resource.deriveDefaultAbstract();

        ContextNode leafNode = new ContextNode(
                resourceUri,
                groupUri,
                ContextType.RESOURCE,
                ContextLayer.L2_DETAIL,
                resource.getTitle() != null ? resource.getTitle() : "未命名资源",
                abstractText,
                0L,
                resource.getUpdatedAt(),
                true
        );

        catalogRepository.upsert(leafNode, userId);
        log.debug("[resource-catalog-sync] 同步资源节点: uri={}", resourceUri.value());

        // 为叶子节点生成向量嵌入
        embedNode(resourceUri.value(), abstractText);
    }

    @Override
    public void removeFromCatalog(ResourceRecordEntity resource) {
        // 当前阶段通过 context_catalog 的逻辑删除实现，
        // 后续可扩展为真正的级联清理。
        log.debug("[resource-catalog-sync] 资源已删除, 目录条目暂保留: uri={}", resource.getRootUri().value());
    }

    /**
     * 确保目录节点存在（upsert 语义，已存在则不覆盖）。
     */
    private void ensureDirectoryNode(ContextUri uri, ContextUri parentUri,
                                     String name, String description, long userId) {
        if (catalogRepository.findByUri(uri.value()).isPresent()) {
            return;
        }

        ContextNode dirNode = new ContextNode(
                uri,
                parentUri,
                ContextType.RESOURCE,
                ContextLayer.L0_ABSTRACT,
                name,
                description,
                0L,
                System.currentTimeMillis(),
                false
        );

        catalogRepository.upsert(dirNode, userId);
        log.debug("[resource-catalog-sync] 创建目录节点: uri={}", uri.value());
    }

    /**
     * 根据来源类型推导分组目录段。
     */
    private String resolveGroupSegment(ResourceSourceType sourceType) {
        return switch (sourceType) {
            case NOTE_TEXT, WEB_CLIP, MARKDOWN_TEXT -> "notes";
            case CHAT_TRANSCRIPT, CHAT_STAGE_SUMMARY -> "chats";
            case OCR_TEXT, PDF_TEXT -> "assets";
        };
    }

    /**
     * 根据来源类型推导分组目录描述。
     */
    private String resolveGroupDescription(ResourceSourceType sourceType) {
        return switch (sourceType) {
            case NOTE_TEXT, WEB_CLIP, MARKDOWN_TEXT -> "笔记类资源";
            case CHAT_TRANSCRIPT, CHAT_STAGE_SUMMARY -> "对话记录类资源";
            case OCR_TEXT, PDF_TEXT -> "附件类资源";
        };
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
}
