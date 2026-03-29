package com.doublez.pocketmindserver.resource.infra.persistence;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class ResourceRecordRepositoryImpl implements ResourceRecordRepository {

    private final ResourceRecordMapper mapper;
    private final ResourceRecordStructMapper structMapper;

    public ResourceRecordRepositoryImpl(ResourceRecordMapper mapper,
                                        ResourceRecordStructMapper structMapper) {
        this.mapper = mapper;
        this.structMapper = structMapper;
    }

    @Override
    public void save(ResourceRecordEntity resourceRecord) {
        ResourceRecordModel model = structMapper.toModel(resourceRecord);
        int rows = mapper.insert(model);
        if (rows != 1) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "resource save failed: uuid=" + resourceRecord.getUuid());
        }
    }

    @Override
    public void update(ResourceRecordEntity resourceRecord) {
        ResourceRecordModel model = structMapper.toModel(resourceRecord);
        int rows = mapper.update(model, new LambdaQueryWrapper<ResourceRecordModel>()
                .eq(ResourceRecordModel::getUuid, resourceRecord.getUuid())
                .eq(ResourceRecordModel::getUserId, resourceRecord.getUserId()));
        if (rows != 1) {
            throw new BusinessException(ApiCode.INTERNAL_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                    "resource update failed: uuid=" + resourceRecord.getUuid());
        }
    }

    @Override
    public Optional<ResourceRecordEntity> findByUuidAndUserId(UUID uuid, long userId) {
        ResourceRecordModel model = mapper.selectOne(new LambdaQueryWrapper<ResourceRecordModel>()
                .eq(ResourceRecordModel::getUuid, uuid)
                .eq(ResourceRecordModel::getUserId, userId));
        return Optional.ofNullable(model).map(structMapper::toDomain);
    }

    @Override
    public Optional<ResourceRecordEntity> findByUuidAndUserIdIncludingDeleted(UUID uuid, long userId) {
        ResourceRecordModel model = mapper.findByUuidAndUserIdIncludingDeleted(uuid, userId);
        return Optional.ofNullable(model).map(structMapper::toDomain);
    }

    @Override
    public Optional<ResourceRecordEntity> findByRootUriAndUserId(String rootUri, long userId) {
        ResourceRecordModel model = mapper.selectOne(new LambdaQueryWrapper<ResourceRecordModel>()
                .eq(ResourceRecordModel::getRootUri, rootUri)
                .eq(ResourceRecordModel::getUserId, userId));
        return Optional.ofNullable(model).map(structMapper::toDomain);
    }

    @Override
    public List<ResourceRecordEntity> findByNoteUuid(long userId, UUID noteUuid) {
        return mapper.findByNoteUuid(userId, noteUuid).stream().map(structMapper::toDomain).toList();
    }

    @Override
    public List<ResourceRecordEntity> findBySessionUuid(long userId, UUID sessionUuid) {
        return mapper.findBySessionUuid(userId, sessionUuid).stream().map(structMapper::toDomain).toList();
    }

    @Override
    public List<ResourceRecordEntity> findByAssetUuid(long userId, UUID assetUuid) {
        return mapper.findByAssetUuid(userId, assetUuid).stream().map(structMapper::toDomain).toList();
    }

    @Override
    public List<ResourceRecordEntity> searchByKeyword(long userId, String keyword, int limit) {
        if (keyword == null || keyword.isBlank() || limit <= 0) {
            return List.of();
        }
        return mapper.searchByKeyword(userId, keyword.trim(), limit).stream().map(structMapper::toDomain).toList();
    }
}
