package com.doublez.pocketmindserver.resource.infra.persistence;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;
import org.mapstruct.NullValuePropertyMappingStrategy;

@Mapper(componentModel = "spring", nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
public interface ResourceRecordStructMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "sourceType", source = "sourceType", qualifiedByName = "sourceTypeToString")
    @Mapping(target = "rootUri", source = "rootUri", qualifiedByName = "contextUriToString")
    @Mapping(target = "status", constant = "ACTIVE")
    @Mapping(target = "isDeleted", source = "deleted")
    ResourceRecordModel toModel(ResourceRecordEntity entity);

    @Mapping(target = "sourceType", source = "sourceType", qualifiedByName = "stringToSourceType")
    @Mapping(target = "rootUri", source = "rootUri", qualifiedByName = "stringToContextUri")
    @Mapping(target = "deleted", source = "isDeleted")
    ResourceRecordEntity toDomain(ResourceRecordModel model);

    @Named("sourceTypeToString")
    default String sourceTypeToString(ResourceSourceType sourceType) {
        return sourceType == null ? null : sourceType.name();
    }

    @Named("stringToSourceType")
    default ResourceSourceType stringToSourceType(String sourceType) {
        return sourceType == null ? null : ResourceSourceType.valueOf(sourceType);
    }

    @Named("contextUriToString")
    default String contextUriToString(ContextUri contextUri) {
        return contextUri == null ? null : contextUri.value();
    }

    @Named("stringToContextUri")
    default ContextUri stringToContextUri(String value) {
        return value == null ? null : ContextUri.of(value);
    }
}
