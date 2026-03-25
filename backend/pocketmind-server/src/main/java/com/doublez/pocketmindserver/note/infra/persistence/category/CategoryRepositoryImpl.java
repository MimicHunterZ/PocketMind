package com.doublez.pocketmindserver.note.infra.persistence.category;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmindserver.note.domain.category.CategoryEntity;
import com.doublez.pocketmindserver.note.domain.category.CategoryRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class CategoryRepositoryImpl implements CategoryRepository {

    private final CategoryMapper mapper;
    private final CategoryStructMapper structMapper;

    public CategoryRepositoryImpl(CategoryMapper mapper, CategoryStructMapper structMapper) {
        this.mapper = mapper;
        this.structMapper = structMapper;
    }

    @Override
    public CategoryEntity save(CategoryEntity category) {
        CategoryModel model = structMapper.toModel(category);
        mapper.insert(model);
        // insert 后 MyBatis-Plus 会回填 id
        return structMapper.toEntity(model);
    }

    @Override
    public void update(CategoryEntity category) {
        CategoryModel model = structMapper.toModel(category);
        mapper.update(model, new LambdaQueryWrapper<CategoryModel>()
                .eq(CategoryModel::getUuid, category.getUuid())
                .eq(CategoryModel::getUserId, category.getUserId()));
    }

    @Override
    public Optional<CategoryEntity> findByUuidAndUserId(UUID uuid, long userId) {
        CategoryModel model = mapper.selectOne(new LambdaQueryWrapper<CategoryModel>()
                .eq(CategoryModel::getUuid, uuid)
                .eq(CategoryModel::getUserId, userId));
        return Optional.ofNullable(model).map(structMapper::toEntity);
    }

    @Override
    public List<CategoryEntity> findByUserId(long userId) {
        return mapper.selectList(new LambdaQueryWrapper<CategoryModel>()
                .eq(CategoryModel::getUserId, userId)
                .orderByAsc(CategoryModel::getName))
                .stream().map(structMapper::toEntity).toList();
    }

    @Override
    public void softDeleteByUuidAndUserId(UUID uuid, long userId, long updatedAt) {
        mapper.softDeleteByUuidAndUserId(uuid, userId, updatedAt);
    }

    @Override
    public void updateServerVersion(UUID uuid, long userId, long serverVersion) {
        mapper.updateServerVersion(uuid, userId, serverVersion);
    }
}
