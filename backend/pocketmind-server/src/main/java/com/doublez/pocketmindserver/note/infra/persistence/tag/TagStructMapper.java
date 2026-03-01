package com.doublez.pocketmindserver.note.infra.persistence.tag;

import com.doublez.pocketmindserver.note.domain.tag.TagEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.NullValueCheckStrategy;
import org.mapstruct.NullValuePropertyMappingStrategy;

/**
 * TagEntity ↔ TagModel 映射接口
 */
@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE,
        nullValueCheckStrategy = NullValueCheckStrategy.ALWAYS
)
public interface TagStructMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "isDeleted", source = "deleted")
    TagModel toModel(TagEntity entity);

    @Mapping(target = "deleted", source = "model.isDeleted")
    TagEntity toEntity(TagModel model);
}
