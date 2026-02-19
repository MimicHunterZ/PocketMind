package com.doublez.pocketmindserver.resource.infra.persistence;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.doublez.pocketmindserver.resource.domain.Resource;
import com.doublez.pocketmindserver.resource.domain.ResourceRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class MybatisResourceRepository implements ResourceRepository {

    private final ResourceMetadataRepository mapper;

    public MybatisResourceRepository(ResourceMetadataRepository mapper) {
        this.mapper = mapper;
    }

    @Override
    public void save(Resource resource) {
        ResourceMetadata model = ResourcePersistenceMapper.toModel(resource);
        int rows = mapper.insert(model);
        if (rows != 1) {
            throw new IllegalStateException("保存资源失败");
        }
    }

    @Override
    public void update(Resource resource) {
        ResourceMetadata model = ResourcePersistenceMapper.toModel(resource);
        int rows = mapper.updateById(model);
        if (rows != 1) {
            throw new IllegalStateException("更新资源失败");
        }
    }

    @Override
    public Optional<Resource> findByIdAndUserId(UUID id, String userId) {
        ResourceMetadata model = mapper.selectOne(
                new LambdaQueryWrapper<ResourceMetadata>()
                        .eq(ResourceMetadata::getId, id)
                        .eq(ResourceMetadata::getUserId, userId)
        );
        if (model == null) {
            return Optional.empty();
        }
        return Optional.of(ResourcePersistenceMapper.toDomain(model));
    }

    @Override
    public List<Resource> findByIdsAndUserId(List<UUID> ids, String userId) {
        List<ResourceMetadata> models = mapper.selectList(
                new LambdaQueryWrapper<ResourceMetadata>()
                        .eq(ResourceMetadata::getUserId, userId)
                        .in(ResourceMetadata::getId, ids)
        );
        return models.stream().map(ResourcePersistenceMapper::toDomain).toList();
    }

    @Override
    public Optional<Resource> findLatestByUrl(String url) {
        Page<ResourceMetadata> page = new Page<>(1L, 1L);
        ResourceMetadata model = mapper.selectPage(
                        page,
                        new LambdaQueryWrapper<ResourceMetadata>()
                                .eq(ResourceMetadata::getOriginalUrl, url)
                                .orderByDesc(ResourceMetadata::getUpdatedAt)
                )
                .getRecords()
                .stream()
                .findFirst()
                .orElse(null);
        if (model == null) {
            return Optional.empty();
        }
        return Optional.of(ResourcePersistenceMapper.toDomain(model));
    }

    @Override
    public List<Resource> findByUrls(List<String> urls) {
        if (urls == null || urls.isEmpty()) {
            return List.of();
        }
        List<ResourceMetadata> models = mapper.selectList(
                new LambdaQueryWrapper<ResourceMetadata>()
                        .in(ResourceMetadata::getOriginalUrl, urls)
        );
        return models.stream().map(ResourcePersistenceMapper::toDomain).toList();
    }
}
