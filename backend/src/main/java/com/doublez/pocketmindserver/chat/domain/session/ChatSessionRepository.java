package com.doublez.pocketmindserver.chat.domain.session;

import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChatSessionRepository {

    void save(ChatSessionEntity session);

    void update(ChatSessionEntity session);

    Optional<ChatSessionEntity> findByUuidAndUserId(UUID uuid, long userId);

    List<ChatSessionEntity> findByUserId(long userId, PageQuery pageQuery);

    List<ChatSessionEntity> findByNoteUuid(long userId, UUID noteUuid);

    List<ChatSessionEntity> findChangedSince(long userId, SyncCursorQuery query);
}
