package com.doublez.pocketmindserver.context.infra.persistence;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.doublez.pocketmindserver.context.domain.ContextRefEntity;
import com.doublez.pocketmindserver.context.domain.ContextRefRepository;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 基于 MyBatis-Plus 的 ContextRef 仓库实现。
 */
@Repository
public class MybatisContextRefRepository implements ContextRefRepository {

    private final ContextRefMapper mapper;

    public MybatisContextRefRepository(ContextRefMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    public void save(ContextRefEntity entity) {
        mapper.insert(toModel(entity));
    }

    @Override
    public void saveBatch(List<ContextRefEntity> entities) {
        if (entities == null || entities.isEmpty()) {
            return;
        }
        for (ContextRefEntity entity : entities) {
            mapper.insert(toModel(entity));
        }
    }

    @Override
    public void upsert(ContextRefEntity entity) {
        ContextRefModel existing = mapper.selectOne(
                new LambdaQueryWrapper<ContextRefModel>()
                        .eq(ContextRefModel::getContextUri, entity.contextUri().value())
                        .eq(ContextRefModel::getBizType, entity.bizType())
                        .eq(ContextRefModel::getUserId, entity.userId())
        );

        if (existing != null) {
            existing.setUpdatedAt(entity.updatedAt());
            existing.setNoteUuid(entity.noteUuid());
            existing.setSessionUuid(entity.sessionUuid());
            existing.setMessageUuid(entity.messageUuid());
            existing.setAssetUuid(entity.assetUuid());
            existing.setSourceUrl(entity.sourceUrl());
            existing.setIsDeleted(entity.deleted());
            mapper.updateById(existing);
        } else {
            mapper.insert(toModel(entity));
        }
    }

    @Override
    public List<ContextRefEntity> findByContextUri(String contextUri, long userId) {
        LambdaQueryWrapper<ContextRefModel> wrapper = new LambdaQueryWrapper<ContextRefModel>()
                .eq(ContextRefModel::getContextUri, contextUri)
                .eq(ContextRefModel::getUserId, userId)
                .select(
                        ContextRefModel::getUuid,
                        ContextRefModel::getUserId,
                        ContextRefModel::getContextUri,
                        ContextRefModel::getBizType,
                        ContextRefModel::getBizId,
                        ContextRefModel::getNoteUuid,
                        ContextRefModel::getSessionUuid,
                        ContextRefModel::getMessageUuid,
                        ContextRefModel::getAssetUuid,
                        ContextRefModel::getSourceUrl,
                        ContextRefModel::getUpdatedAt,
                        ContextRefModel::getIsDeleted
                )
                .orderByDesc(ContextRefModel::getUpdatedAt);
        return mapper.selectList(wrapper).stream().map(this::toEntity).toList();
    }

    @Override
    public List<ContextRefEntity> findBySessionUuid(UUID sessionUuid, long userId) {
        LambdaQueryWrapper<ContextRefModel> wrapper = new LambdaQueryWrapper<ContextRefModel>()
                .eq(ContextRefModel::getSessionUuid, sessionUuid)
                .eq(ContextRefModel::getUserId, userId)
                .select(
                        ContextRefModel::getUuid,
                        ContextRefModel::getUserId,
                        ContextRefModel::getContextUri,
                        ContextRefModel::getBizType,
                        ContextRefModel::getBizId,
                        ContextRefModel::getNoteUuid,
                        ContextRefModel::getSessionUuid,
                        ContextRefModel::getMessageUuid,
                        ContextRefModel::getAssetUuid,
                        ContextRefModel::getSourceUrl,
                        ContextRefModel::getUpdatedAt,
                        ContextRefModel::getIsDeleted
                )
                .orderByDesc(ContextRefModel::getUpdatedAt);
        return mapper.selectList(wrapper).stream().map(this::toEntity).toList();
    }

    @Override
    public List<ContextRefEntity> findByNoteUuid(UUID noteUuid, long userId) {
        LambdaQueryWrapper<ContextRefModel> wrapper = new LambdaQueryWrapper<ContextRefModel>()
                .eq(ContextRefModel::getNoteUuid, noteUuid)
                .eq(ContextRefModel::getUserId, userId)
                .select(
                        ContextRefModel::getUuid,
                        ContextRefModel::getUserId,
                        ContextRefModel::getContextUri,
                        ContextRefModel::getBizType,
                        ContextRefModel::getBizId,
                        ContextRefModel::getNoteUuid,
                        ContextRefModel::getSessionUuid,
                        ContextRefModel::getMessageUuid,
                        ContextRefModel::getAssetUuid,
                        ContextRefModel::getSourceUrl,
                        ContextRefModel::getUpdatedAt,
                        ContextRefModel::getIsDeleted
                )
                .orderByDesc(ContextRefModel::getUpdatedAt);
        return mapper.selectList(wrapper).stream().map(this::toEntity).toList();
    }

    @Override
    public Optional<ContextRefEntity> findByUuid(UUID uuid) {
        ContextRefModel model = mapper.selectOne(
                new LambdaQueryWrapper<ContextRefModel>()
                        .eq(ContextRefModel::getUuid, uuid)
                        .select(
                                ContextRefModel::getUuid,
                                ContextRefModel::getUserId,
                                ContextRefModel::getContextUri,
                                ContextRefModel::getBizType,
                                ContextRefModel::getBizId,
                                ContextRefModel::getNoteUuid,
                                ContextRefModel::getSessionUuid,
                                ContextRefModel::getMessageUuid,
                                ContextRefModel::getAssetUuid,
                                ContextRefModel::getSourceUrl,
                                ContextRefModel::getUpdatedAt,
                                ContextRefModel::getIsDeleted
                        )
        );
        return Optional.ofNullable(model).map(this::toEntity);
    }

    @Override
    public void softDelete(UUID uuid) {
        mapper.update(null, new LambdaUpdateWrapper<ContextRefModel>()
                .eq(ContextRefModel::getUuid, uuid)
                .set(ContextRefModel::getIsDeleted, true)
                .set(ContextRefModel::getUpdatedAt, System.currentTimeMillis()));
    }

    // ─── 模型转换 ──────────────────────────────────────────────────

    private ContextRefModel toModel(ContextRefEntity entity) {
        ContextRefModel model = new ContextRefModel();
        model.setUuid(entity.uuid());
        model.setUserId(entity.userId());
        model.setContextUri(entity.contextUri().value());
        model.setBizType(entity.bizType());
        model.setBizId(entity.bizId());
        model.setNoteUuid(entity.noteUuid());
        model.setSessionUuid(entity.sessionUuid());
        model.setMessageUuid(entity.messageUuid());
        model.setAssetUuid(entity.assetUuid());
        model.setSourceUrl(entity.sourceUrl());
        model.setUpdatedAt(entity.updatedAt());
        model.setIsDeleted(entity.deleted());
        return model;
    }

    private ContextRefEntity toEntity(ContextRefModel model) {
        return new ContextRefEntity(
                model.getUuid(),
                model.getUserId() != null ? model.getUserId() : 0L,
                ContextUri.of(model.getContextUri()),
                model.getBizType(),
                model.getBizId(),
                model.getNoteUuid(),
                model.getSessionUuid(),
                model.getMessageUuid(),
                model.getAssetUuid(),
                model.getSourceUrl(),
                model.getUpdatedAt() != null ? model.getUpdatedAt() : 0L,
                Boolean.TRUE.equals(model.getIsDeleted())
        );
    }
}
