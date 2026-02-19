package com.doublez.pocketmindserver.note.infra.persistence.category;

import com.doublez.pocketmindserver.note.domain.category.CategoryEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.NullValueCheckStrategy;
import org.mapstruct.NullValuePropertyMappingStrategy;

/**
 * CategoryEntity ↔ CategoryModel 映射接口
 */
@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE,
        nullValueCheckStrategy = NullValueCheckStrategy.ALWAYS
)
public interface CategoryStructMapper {

    /**
     * 新增分类时，id 由数据库自增生成
     */
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "isDeleted", source = "deleted")
    CategoryModel toModel(CategoryEntity entity);

    @Mapping(target = "deleted", source = "model.isDeleted")
    CategoryEntity toEntity(CategoryModel model);
}
