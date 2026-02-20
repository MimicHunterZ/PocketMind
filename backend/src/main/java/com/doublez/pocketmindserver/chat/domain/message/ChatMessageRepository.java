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
     * 说明：这是为了“边流式返回边落库防断连”的业务诉求引入的仓储能力。
     */
    void appendContent(UUID messageUuid, long userId, String delta, long updatedAt);

    Optional<ChatMessageEntity> findByUuidAndUserId(UUID uuid, long userId);

    /**
     * 按时间正序分页拉取历史消息
     */
    List<ChatMessageEntity> findBySessionUuid(long userId, UUID sessionUuid, PageQuery pageQuery);

    List<ChatMessageEntity> findChangedSince(long userId, SyncCursorQuery query);

    /**
     * 从叶节点沿 parent_uuid 链向上追溯，返回完整对话链（从链头到叶节点，正序排列）。
     * 用于重新生成、分支对话等场景，重建当前分支的完整上下文。
     *
     * @param leafUuid 叶节点消息 uuid
     * @param userId   当前用户 id（防止越权）
     * @return 从链头到叶节点的消息列表（正序）
     */
    List<ChatMessageEntity> findChain(UUID leafUuid, long userId);
}
