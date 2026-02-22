package com.doublez.pocketmindserver.attachment.infra.persistence.common;

import com.doublez.pocketmindserver.attachment.domain.attachment.AttachmentEntity;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionEntity;
import com.doublez.pocketmindserver.attachment.infra.persistence.attachment.AttachmentModel;
import com.doublez.pocketmindserver.attachment.infra.persistence.vision.AttachmentVisionModel;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.NullValueCheckStrategy;
import org.mapstruct.NullValuePropertyMappingStrategy;

/**
 * Attachment / Vision 的领域实体 ↔ 持久化模型 映射接口
 * 由 MapStruct 在编译期自动生成实现类
 */
@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE,
        nullValueCheckStrategy = NullValueCheckStrategy.ALWAYS
)
public interface AttachmentStructMapper {

    // -------------------- Attachment --------------------

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "isDeleted", source = "deleted")
    AttachmentModel toModel(AttachmentEntity entity);

    @Mapping(target = "deleted", source = "isDeleted")
    AttachmentEntity toDomain(AttachmentModel model);

    // -------------------- Vision --------------------

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "isDeleted", source = "deleted")
    @Mapping(target = "assetUuid", source = "assetUuid")
    @Mapping(target = "content", source = "content")
    @Mapping(target = "contentType", source = "contentType")
    @Mapping(target = "noteUuid", source = "noteUuid")
    AttachmentVisionModel toVisionModel(AttachmentVisionEntity entity);

    @Mapping(target = "deleted", source = "isDeleted")
    @Mapping(target = "assetUuid", source = "assetUuid")
    @Mapping(target = "content", source = "content")
    @Mapping(target = "contentType", source = "contentType")
    @Mapping(target = "noteUuid", source = "noteUuid")
    AttachmentVisionEntity toVisionDomain(AttachmentVisionModel model);
}
