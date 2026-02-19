package com.doublez.pocketmindserver.note.infra.persistence.note;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteResourceStatus;
import com.doublez.pocketmindserver.note.domain.note.NoteTag;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.NullValueCheckStrategy;
import org.mapstruct.NullValuePropertyMappingStrategy;

/**
 * NoteEntity ↔ NoteModel 映射接口
 * <p>
 * 由 MapStruct 在编译期自动生成实现类，消除手写转换易遗漏字段的风险。
 * 新增字段只需同时加入 entity 和 model 即可自动映射（字段名一致时）。
 */
@Mapper(
        componentModel = "spring",
        // source 为 null 时不覆盖 target 已有值（用于局部 patch 更新场景）
    nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE,
    nullValueCheckStrategy = NullValueCheckStrategy.ALWAYS
)
public interface NoteStructMapper {

    /**
     * 领域实体 → 持久化模型
     * {@code deleted} → {@code isDeleted} 字段名不同，需显式映射
     */
    @Mapping(target = "isDeleted", source = "deleted")
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    NoteModel toModel(NoteEntity entity);

    /**
     * 持久化模型 → 领域实体
     * <ul>
     *   <li>{@code isDeleted} → {@code deleted}</li>
     *   <li>{@code categoryId} 为 null 时默认 1（与建表 DEFAULT 1 保持一致）</li>
     *   <li>{@code resourceStatus} 为 null 时默认 NONE</li>
     *   <li>{@code id} / {@code createdAt} 仅存在于 Model，Entity 不需要</li>
     * </ul>
     */
    @Mapping(target = "deleted", source = "model.isDeleted")
    @Mapping(target = "categoryId", defaultValue = "1L")
    @Mapping(target = "resourceStatus", defaultExpression = "java(com.doublez.pocketmindserver.note.domain.note.NoteResourceStatus.NONE)")
    NoteEntity toDomain(NoteModel model, java.util.List<NoteTag> tags);
}
