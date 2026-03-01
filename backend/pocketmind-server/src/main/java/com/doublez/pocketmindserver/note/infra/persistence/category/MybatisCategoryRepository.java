package com.doublez.pocketmindserver.note.infra.persistence.category;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmindserver.note.domain.category.CategoryEntity;
import com.doublez.pocketmindserver.note.domain.category.CategoryRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * CategoryRepository 的 MyBatis-Plus 实现
 */
@Repository
public class MybatisCategoryRepository implements CategoryRepository {

    private final CategoryMapper mapper;
    private final CategoryStructMapper structMapper;

    public MybatisCategoryRepository(CategoryMapper mapper, CategoryStructMapper structMapper) {
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
    public Optional<CategoryEntity> findByIdAndUserId(long id, long userId) {
        CategoryModel model = mapper.selectOne(new LambdaQueryWrapper<CategoryModel>()
                .eq(CategoryModel::getId, id)
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
    public void deleteByIdAndUserId(long id, long userId) {
        mapper.softDeleteByIdAndUserId(id, userId, System.currentTimeMillis());
    }
}
