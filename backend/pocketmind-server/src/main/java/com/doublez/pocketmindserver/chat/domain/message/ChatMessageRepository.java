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
     */
    List<ChatMessageEntity> findChain(UUID leafUuid, long userId);

    /**
     * 查询指定节点的所有直接子节点（即从该节点分叉出的第一层消息）。
     * 用于获取可供导航的分支列表。
     */
    List<ChatMessageEntity> findChildrenByParentUuid(UUID parentUuid, long userId);

    /**
     * 更新消息评分。
     * @param rating 1=点赞，0=取消，-1=点踩
     */
    void updateRating(UUID uuid, long userId, int rating);

    /**
     * 更新 USER 消息内容（编辑消息场景）。
     */
    void updateContent(UUID uuid, long userId, String content);

    /**
     * 更新分支别名（AI 静默生成后写入叶节点）。
     */
    void updateBranchAlias(UUID uuid, long userId, String alias);

    /**
     * 批量软删除消息。
     */
    void softDeleteByUuids(List<UUID> uuids, long userId);

    /**
     * 软删除指定父消息节点的所有 ASSISTANT 子消息（单次 SQL，用于编辑 USER 消息后清理回复）。
     */
    void softDeleteAssistantChildren(UUID parentUuid, long userId);
}
