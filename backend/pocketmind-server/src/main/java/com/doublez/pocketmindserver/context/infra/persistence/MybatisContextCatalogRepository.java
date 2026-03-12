package com.doublez.pocketmindserver.context.infra.persistence;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextLayer;
import com.doublez.pocketmindserver.context.domain.ContextNode;
import com.doublez.pocketmindserver.context.domain.ContextType;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 基于 MyBatis-Plus 的 ContextCatalog 仓库实现。
 */
@Repository
public class MybatisContextCatalogRepository implements ContextCatalogRepository {

    private final ContextCatalogMapper mapper;

    public MybatisContextCatalogRepository(ContextCatalogMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    public List<ContextNode> findChildrenByParentUri(String parentUri, long userId) {
        LambdaQueryWrapper<ContextCatalogModel> wrapper = new LambdaQueryWrapper<ContextCatalogModel>()
                .eq(ContextCatalogModel::getParentUri, parentUri)
                .eq(ContextCatalogModel::getUserId, userId)
                .select(
                        ContextCatalogModel::getUri,
                        ContextCatalogModel::getParentUri,
                        ContextCatalogModel::getContextType,
                        ContextCatalogModel::getLayer,
                        ContextCatalogModel::getName,
                        ContextCatalogModel::getAbstractText,
                        ContextCatalogModel::getActiveCount,
                        ContextCatalogModel::getUpdatedAt,
                        ContextCatalogModel::getIsLeaf
                )
                .orderByDesc(ContextCatalogModel::getUpdatedAt);
        return mapper.selectList(wrapper).stream().map(this::toNode).toList();
    }

    @Override
    public List<ContextNode> findDescendantsByUriPrefix(String uriPrefix, long userId) {
        LambdaQueryWrapper<ContextCatalogModel> wrapper = new LambdaQueryWrapper<ContextCatalogModel>()
                .likeRight(ContextCatalogModel::getUri, uriPrefix)
                .eq(ContextCatalogModel::getUserId, userId)
                .select(
                        ContextCatalogModel::getUri,
                        ContextCatalogModel::getParentUri,
                        ContextCatalogModel::getContextType,
                        ContextCatalogModel::getLayer,
                        ContextCatalogModel::getName,
                        ContextCatalogModel::getAbstractText,
                        ContextCatalogModel::getActiveCount,
                        ContextCatalogModel::getUpdatedAt,
                        ContextCatalogModel::getIsLeaf
                )
                .orderByDesc(ContextCatalogModel::getUpdatedAt);
        return mapper.selectList(wrapper).stream().map(this::toNode).toList();
    }

    @Override
    public List<ContextNode> searchByKeyword(String keyword, Long userId, ContextType contextType, int limit) {
        LambdaQueryWrapper<ContextCatalogModel> wrapper = new LambdaQueryWrapper<ContextCatalogModel>()
                .and(w -> w.like(ContextCatalogModel::getName, keyword)
                        .or()
                        .like(ContextCatalogModel::getAbstractText, keyword))
                .eq(userId != null, ContextCatalogModel::getUserId, userId)
                .eq(contextType != null, ContextCatalogModel::getContextType, contextType.name())
                .select(
                        ContextCatalogModel::getUri,
                        ContextCatalogModel::getParentUri,
                        ContextCatalogModel::getContextType,
                        ContextCatalogModel::getLayer,
                        ContextCatalogModel::getName,
                        ContextCatalogModel::getAbstractText,
                        ContextCatalogModel::getActiveCount,
                        ContextCatalogModel::getUpdatedAt,
                        ContextCatalogModel::getIsLeaf
                )
                .orderByDesc(ContextCatalogModel::getUpdatedAt)
                .last("LIMIT " + limit);
        return mapper.selectList(wrapper).stream().map(this::toNode).toList();
    }

    @Override
    public Optional<ContextNode> findByUri(String uri) {
        LambdaQueryWrapper<ContextCatalogModel> wrapper = new LambdaQueryWrapper<ContextCatalogModel>()
                .eq(ContextCatalogModel::getUri, uri)
                .select(
                        ContextCatalogModel::getUri,
                        ContextCatalogModel::getParentUri,
                        ContextCatalogModel::getContextType,
                        ContextCatalogModel::getLayer,
                        ContextCatalogModel::getName,
                        ContextCatalogModel::getAbstractText,
                        ContextCatalogModel::getActiveCount,
                        ContextCatalogModel::getUpdatedAt,
                        ContextCatalogModel::getIsLeaf
                );
        ContextCatalogModel model = mapper.selectOne(wrapper);
        return Optional.ofNullable(model).map(this::toNode);
    }

    @Override
    public List<ContextNode> findByUris(List<String> uris) {
        if (uris == null || uris.isEmpty()) {
            return List.of();
        }
        LambdaQueryWrapper<ContextCatalogModel> wrapper = new LambdaQueryWrapper<ContextCatalogModel>()
                .in(ContextCatalogModel::getUri, uris)
                .select(
                        ContextCatalogModel::getUri,
                        ContextCatalogModel::getParentUri,
                        ContextCatalogModel::getContextType,
                        ContextCatalogModel::getLayer,
                        ContextCatalogModel::getName,
                        ContextCatalogModel::getAbstractText,
                        ContextCatalogModel::getActiveCount,
                        ContextCatalogModel::getUpdatedAt,
                        ContextCatalogModel::getIsLeaf
                );
        return mapper.selectList(wrapper).stream().map(this::toNode).toList();
    }

    @Override
    public void upsert(ContextNode node, Long userId) {
        ContextCatalogModel existing = mapper.selectOne(
                new LambdaQueryWrapper<ContextCatalogModel>()
                        .eq(ContextCatalogModel::getUri, node.uri().value()));

        if (existing != null) {
            existing.setName(node.name());
            existing.setAbstractText(node.abstractText());
            existing.setLayer(node.layer().name());
            existing.setIsLeaf(node.isLeaf());
            existing.setUpdatedAt(node.updatedAt());
            mapper.updateById(existing);
        } else {
            ContextCatalogModel model = new ContextCatalogModel();
            model.setUuid(UUID.randomUUID());
            model.setUserId(userId);
            model.setContextType(node.contextType().name());
            model.setUri(node.uri().value());
            model.setParentUri(node.parentUri() != null ? node.parentUri().value() : null);
            model.setName(node.name());
            model.setAbstractText(node.abstractText());
            model.setLayer(node.layer().name());
            model.setStatus("ACTIVE");
            model.setIsLeaf(node.isLeaf());
            model.setActiveCount(0L);
            model.setUpdatedAt(node.updatedAt());
            mapper.insert(model);
        }
    }

    @Override
    public void incrementActiveCount(String uri) {
        mapper.update(null, new LambdaUpdateWrapper<ContextCatalogModel>()
                .eq(ContextCatalogModel::getUri, uri)
                .setSql("active_count = active_count + 1"));
    }

    @Override
    public void incrementActiveCountBatch(List<String> uris) {
        if (uris == null || uris.isEmpty()) {
            return;
        }
        mapper.update(null, new LambdaUpdateWrapper<ContextCatalogModel>()
                .in(ContextCatalogModel::getUri, uris)
                .setSql("active_count = active_count + 1"));
    }

    // ─── 转换 ──────────────────────────────────────────────────

    private ContextNode toNode(ContextCatalogModel model) {
        return new ContextNode(
                ContextUri.of(model.getUri()),
                model.getParentUri() != null ? ContextUri.of(model.getParentUri()) : null,
                ContextType.valueOf(model.getContextType()),
                ContextLayer.valueOf(model.getLayer()),
                model.getName(),
                model.getAbstractText(),
                model.getActiveCount() != null ? model.getActiveCount() : 0L,
                model.getUpdatedAt() != null ? model.getUpdatedAt() : 0L,
                Boolean.TRUE.equals(model.getIsLeaf())
        );
    }

    // ─── 向量搜索 ──────────────────────────────────────────────

    @Override
    public List<ScoredCatalogEntry> searchByVector(float[] queryVector, long userId, ContextType contextType, int limit) {
        String vectorStr = toVectorString(queryVector);
        String ctxType = contextType != null ? contextType.name() : null;
        return mapper.searchByVector(vectorStr, userId, ctxType, limit).stream()
                .map(this::toScoredEntry)
                .toList();
    }

    @Override
    public List<ScoredCatalogEntry> searchChildrenByVector(float[] queryVector, String parentUri, long userId, int limit) {
        String vectorStr = toVectorString(queryVector);
        return mapper.searchChildrenByVector(vectorStr, parentUri, userId, limit).stream()
                .map(this::toScoredEntry)
                .toList();
    }

    @Override
    public void updateEmbedding(String uri, float[] embedding) {
        if (embedding == null) return;
        mapper.updateEmbedding(uri, toVectorString(embedding));
    }

    private ScoredCatalogEntry toScoredEntry(java.util.Map<String, Object> row) {
        ContextNode node = new ContextNode(
                ContextUri.of((String) row.get("uri")),
                row.get("parent_uri") != null ? ContextUri.of((String) row.get("parent_uri")) : null,
                ContextType.valueOf((String) row.get("context_type")),
                ContextLayer.valueOf((String) row.get("layer")),
                (String) row.get("name"),
                (String) row.get("abstract_text"),
                row.get("active_count") != null ? ((Number) row.get("active_count")).longValue() : 0L,
                row.get("updated_at") != null ? ((Number) row.get("updated_at")).longValue() : 0L,
                row.get("is_leaf") != null && (Boolean) row.get("is_leaf")
        );
        double similarity = row.get("similarity") != null ? ((Number) row.get("similarity")).doubleValue() : 0.0;
        return new ScoredCatalogEntry(node, similarity);
    }

    private String toVectorString(float[] vector) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < vector.length; i++) {
            if (i > 0) sb.append(',');
            sb.append(vector[i]);
        }
        sb.append(']');
        return sb.toString();
    }
}
