package com.doublez.pocketmindserver.chat.infra.persistence.session;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
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


@Repository
public class MybatisChatSessionRepository implements ChatSessionRepository {

    private final ChatSessionMapper mapper;
    private final ChatStructMapper chatStructMapper;

    public MybatisChatSessionRepository(ChatSessionMapper mapper, ChatStructMapper chatStructMapper) {
        this.mapper = mapper;
        this.chatStructMapper = chatStructMapper;
    }

    @Override
    public void save(ChatSessionEntity session) {
        ChatSessionModel model = chatStructMapper.toSessionModel(session);
        int rows = mapper.insert(model);
        if (rows != 1) {
            throw new BusinessException(ApiCode.CHAT_SESSION_SAVE_FAILED, HttpStatus.INTERNAL_SERVER_ERROR,
                    "uuid=" + session.getUuid());
        }
    }

    @Override
    public void update(ChatSessionEntity session) {
        ChatSessionModel model = chatStructMapper.toSessionModel(session);
        mapper.update(model, new LambdaQueryWrapper<ChatSessionModel>()
                .eq(ChatSessionModel::getUuid, session.getUuid())
                .eq(ChatSessionModel::getUserId, session.getUserId()));
    }

    @Override
    public Optional<ChatSessionEntity> findByUuidAndUserId(UUID uuid, long userId) {
        ChatSessionModel model = mapper.selectOne(new LambdaQueryWrapper<ChatSessionModel>()
                .eq(ChatSessionModel::getUuid, uuid)
                .eq(ChatSessionModel::getUserId, userId));
        return Optional.ofNullable(model).map(chatStructMapper::toSessionDomain);
    }

    @Override
    public List<ChatSessionEntity> findByUserId(long userId, PageQuery pageQuery) {
        Page<ChatSessionModel> page = new Page<>(pageQuery.pageIndex() + 1L, pageQuery.pageSize());
        return mapper.selectPage(page, new LambdaQueryWrapper<ChatSessionModel>()
                .eq(ChatSessionModel::getUserId, userId)
            .orderByDesc(ChatSessionModel::getUpdatedAt))
            .getRecords()
            .stream()
            .map(chatStructMapper::toSessionDomain)
            .toList();
    }

    @Override
    public List<ChatSessionEntity> findByNoteUuid(long userId, UUID noteUuid) {
        return mapper.findByNoteUuid(userId, noteUuid)
                .stream().map(chatStructMapper::toSessionDomain).toList();
    }

    @Override
    public List<ChatSessionEntity> findChangedSince(long userId, SyncCursorQuery query) {
        return mapper.findChangedSince(userId, query.cursor(), query.limit())
                .stream().map(chatStructMapper::toSessionDomain).toList();
    }
}