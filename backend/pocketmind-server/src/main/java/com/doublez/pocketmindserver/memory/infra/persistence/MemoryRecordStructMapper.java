package com.doublez.pocketmindserver.memory.infra.persistence;

import com.doublez.pocketmindserver.context.domain.ContextStatus;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.context.domain.SpaceType;
import com.doublez.pocketmindserver.memory.domain.MemoryRecordEntity;
import com.doublez.pocketmindserver.memory.domain.MemoryType;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;
import org.mapstruct.NullValuePropertyMappingStrategy;

/**
 * MemoryRecordEntity ↔ MemoryRecordModel 的 MapStruct 映射器。
 */
@Mapper(componentModel = "spring", nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
public interface MemoryRecordStructMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "spaceType", source = "spaceType", qualifiedByName = "spaceTypeToString")
    @Mapping(target = "memoryType", source = "memoryType", qualifiedByName = "memoryTypeToString")
    @Mapping(target = "rootUri", source = "rootUri", qualifiedByName = "contextUriToString")
    @Mapping(target = "status", source = "status", qualifiedByName = "statusToString")
    @Mapping(target = "isDeleted", source = "deleted")
    MemoryRecordModel toModel(MemoryRecordEntity entity);

    @Mapping(target = "spaceType", source = "spaceType", qualifiedByName = "stringToSpaceType")
    @Mapping(target = "memoryType", source = "memoryType", qualifiedByName = "stringToMemoryType")
    @Mapping(target = "rootUri", source = "rootUri", qualifiedByName = "stringToContextUri")
    @Mapping(target = "status", source = "status", qualifiedByName = "stringToStatus")
    @Mapping(target = "deleted", source = "isDeleted")
    MemoryRecordEntity toDomain(MemoryRecordModel model);

    // ─── 枚举 ↔ String 转换 ──────────────────────────

    @Named("spaceTypeToString")
    default String spaceTypeToString(SpaceType spaceType) {
        return spaceType == null ? null : spaceType.name();
    }

    @Named("stringToSpaceType")
    default SpaceType stringToSpaceType(String value) {
        return value == null ? null : SpaceType.valueOf(value);
    }

    @Named("memoryTypeToString")
    default String memoryTypeToString(MemoryType memoryType) {
        return memoryType == null ? null : memoryType.name();
    }

    @Named("stringToMemoryType")
    default MemoryType stringToMemoryType(String value) {
        return value == null ? null : MemoryType.valueOf(value);
    }

    @Named("contextUriToString")
    default String contextUriToString(ContextUri contextUri) {
        return contextUri == null ? null : contextUri.value();
    }

    @Named("stringToContextUri")
    default ContextUri stringToContextUri(String value) {
        return value == null ? null : ContextUri.of(value);
    }

    @Named("statusToString")
    default String statusToString(ContextStatus status) {
        return status == null ? null : status.name();
    }

    @Named("stringToStatus")
    default ContextStatus stringToStatus(String value) {
        return value == null ? null : ContextStatus.valueOf(value);
    }
}
