package com.doublez.pocketmindserver.chat.domain.message;

import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.domain.SyncCursorQuery;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ChatMessageRepository {

    void save(ChatMessageEntity message);

    /**
     * 流式生成场景：增量追加消息内容，并同步 updatedAt。
     * <p>
     * 说明：这是为了“边流式返回边落库防断连”的业务诉求引入的仓储能力。
     */
    void appendContent(UUID messageUuid, long userId, String delta, long updatedAt);

    Optional<ChatMessageEntity> findByUuidAndUserId(UUID uuid, long userId);

    /**
     * 按时间正序分页拉取历史消息
     */
    List<ChatMessageEntity> findBySessionUuid(long userId, UUID sessionUuid, PageQuery pageQuery);

    List<ChatMessageEntity> findChangedSince(long userId, SyncCursorQuery query);
}
