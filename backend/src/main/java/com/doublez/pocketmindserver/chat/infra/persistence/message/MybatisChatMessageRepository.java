package com.doublez.pocketmindserver.chat.infra.persistence.message;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.infra.persistence.common.ChatStructMapper;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * ChatMessageRepository 的 MyBatis-Plus 实现
 */
@Repository
public class MybatisChatMessageRepository implements ChatMessageRepository {

    private final ChatMessageMapper mapper;
    private final ChatStructMapper chatStructMapper;

    public MybatisChatMessageRepository(ChatMessageMapper mapper, ChatStructMapper chatStructMapper) {
        this.mapper = mapper;
        this.chatStructMapper = chatStructMapper;
    }

    @Override
    public void save(ChatMessageEntity message) {
        ChatMessageModel model = chatStructMapper.toMessageModel(message);
        int rows = mapper.insert(model);
        if (rows != 1) {
            throw new BusinessException(ApiCode.CHAT_MESSAGE_SAVE_FAILED, HttpStatus.INTERNAL_SERVER_ERROR,
                    "uuid=" + message.getUuid());
        }
    }

    @Override
    public void appendContent(UUID messageUuid, long userId, String delta, long updatedAt) {
        if (delta == null || delta.isEmpty()) {
            return;
        }
        int rows = mapper.appendContent(messageUuid, userId, delta, updatedAt);
        if (rows != 1) {
            throw new BusinessException(ApiCode.CHAT_MESSAGE_UPDATE_FAILED, HttpStatus.INTERNAL_SERVER_ERROR,
                    "uuid=" + messageUuid);
        }
    }

    @Override
    public Optional<ChatMessageEntity> findByUuidAndUserId(UUID uuid, long userId) {
        ChatMessageModel model = mapper.selectOne(new LambdaQueryWrapper<ChatMessageModel>()
                .eq(ChatMessageModel::getUuid, uuid)
                .eq(ChatMessageModel::getUserId, userId));
        return Optional.ofNullable(model).map(chatStructMapper::toMessageDomain);
    }

    @Override
    public List<ChatMessageEntity> findBySessionUuid(long userId, UUID sessionUuid, PageQuery pageQuery) {
        return mapper.findBySessionUuid(userId, sessionUuid, pageQuery.limit(), pageQuery.offset())
                .stream().map(chatStructMapper::toMessageDomain).toList();
    }

    @Override
    public List<ChatMessageEntity> findChangedSince(long userId, SyncCursorQuery query) {
        return mapper.findChangedSince(userId, query.cursor(), query.limit())
                .stream().map(chatStructMapper::toMessageDomain).toList();
    }

    @Override
    public List<ChatMessageEntity> findChain(UUID leafUuid, long userId) {
        return mapper.findChain(leafUuid, userId)
                .stream().map(chatStructMapper::toMessageDomain).toList();
    }
}