package com.doublez.pocketmindserver.chat.infra.persistence.common;

import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.infra.persistence.message.ChatMessageModel;
import com.doublez.pocketmindserver.chat.infra.persistence.session.ChatSessionModel;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.NullValuePropertyMappingStrategy;

/**
 * MapStruct 双向转换：聊天会话 / 消息 的领域实体 ↔ 持久化模型
 */
@Mapper(componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
public interface ChatStructMapper {

    // ChatSessionEntity ↔ ChatSessionModel-
    /** 领域实体 → 持久化模型（entity.deleted → model.isDeleted） */
    @Mapping(target = "isDeleted", source = "deleted")
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    ChatSessionModel toSessionModel(ChatSessionEntity entity);

    /** 持久化模型 → 领域实体（model.isDeleted → entity.deleted；null updatedAt → 0） */
    @Mapping(target = "deleted", source = "isDeleted")
    @Mapping(target = "updatedAt", defaultValue = "0L")
    ChatSessionEntity toSessionDomain(ChatSessionModel model);

    // ChatMessageEntity ↔ ChatMessageModel
    /** 领域实体 → 持久化模型 */
    @Mapping(target = "isDeleted", source = "deleted")
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    ChatMessageModel toMessageModel(ChatMessageEntity entity);

    /** 持久化模型 → 领域实体 */
    @Mapping(target = "deleted", source = "isDeleted")
    @Mapping(target = "updatedAt", defaultValue = "0L")
    @Mapping(target = "messageType", defaultValue = "TEXT")
    ChatMessageEntity toMessageDomain(ChatMessageModel model);
}
