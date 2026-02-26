package com.doublez.pocketmindserver.chat.infra.persistence.message;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;
import java.util.UUID;

@Mapper
public interface ChatMessageMapper extends BaseMapper<ChatMessageModel> {

    @Select("""
            SELECT * FROM chat_messages
            WHERE user_id = #{userId}
              AND session_uuid = #{sessionUuid}
              AND is_deleted = FALSE
            ORDER BY created_at ASC
            LIMIT #{limit} OFFSET #{offset}
            """)
    List<ChatMessageModel> findBySessionUuid(
            @Param("userId") long userId,
            @Param("sessionUuid") UUID sessionUuid,
            @Param("limit") int limit,
            @Param("offset") int offset);

    @Select("""
            SELECT * FROM chat_messages
            WHERE user_id = #{userId}
              AND updated_at > #{cursor}
            ORDER BY updated_at ASC
            LIMIT #{limit}
            """)
    List<ChatMessageModel> findChangedSince(
            @Param("userId") long userId,
            @Param("cursor") long cursor,
            @Param("limit") int limit);

    /**
     * 追加消息内容（用于流式输出防断连），并更新 updated_at。
     */
    @Update("""
            UPDATE chat_messages
               SET content = COALESCE(content, '') || #{delta},
                   updated_at = #{updatedAt}
             WHERE uuid = #{messageUuid}
               AND user_id = #{userId}
               AND is_deleted = FALSE
            """)
    int appendContent(@Param("messageUuid") UUID messageUuid,
                      @Param("userId") long userId,
                      @Param("delta") String delta,
                      @Param("updatedAt") long updatedAt);

    /**
     * 从叶节点沿 parent_uuid 链递归向上追溯，返回完整对话链（正序排列）。
     * 使用 PostgreSQL WITH RECURSIVE CTE 实现链表遍历。
     */
    @Select("""
            WITH RECURSIVE chain AS (
                SELECT * FROM chat_messages
                 WHERE uuid = #{leafUuid}::uuid
                   AND user_id = #{userId}
                   AND is_deleted = FALSE
                UNION ALL
                SELECT m.* FROM chat_messages m
                  JOIN chain c ON m.uuid = c.parent_uuid
                 WHERE m.user_id = #{userId}
                   AND m.is_deleted = FALSE
            )
            SELECT * FROM chain
            ORDER BY created_at ASC
            """)
    List<ChatMessageModel> findChain(
            @Param("leafUuid") UUID leafUuid,
            @Param("userId") long userId);

    /**
     * 查询指定节点的直接子节点（用于获取分叉分支）。
     */
    @Select("""
            SELECT * FROM chat_messages
             WHERE parent_uuid = #{parentUuid}::uuid
               AND user_id = #{userId}
               AND is_deleted = FALSE
            ORDER BY created_at ASC
            """)
    List<ChatMessageModel> findChildrenByParentUuid(
            @Param("parentUuid") UUID parentUuid,
            @Param("userId") long userId);

    /**
     * 更新消息评分。
     */
    @Update("""
            UPDATE chat_messages
               SET rating = #{rating},
                   updated_at = #{updatedAt}
             WHERE uuid = #{uuid}::uuid
               AND user_id = #{userId}
               AND is_deleted = FALSE
            """)
    int updateRating(
            @Param("uuid") UUID uuid,
            @Param("userId") long userId,
            @Param("rating") int rating,
            @Param("updatedAt") long updatedAt);

    /**
     * 更新消息内容（用于编辑 USER 消息）。
     */
    @Update("""
            UPDATE chat_messages
               SET content = #{content},
                   updated_at = #{updatedAt}
             WHERE uuid = #{uuid}::uuid
               AND user_id = #{userId}
               AND role = 'USER'
               AND is_deleted = FALSE
            """)
    int updateContent(
            @Param("uuid") UUID uuid,
            @Param("userId") long userId,
            @Param("content") String content,
            @Param("updatedAt") long updatedAt);

    /**
     * 更新分支别名（由 AI 静默生成后写入）。
     */
    @Update("""
            UPDATE chat_messages
               SET branch_alias = #{alias},
                   updated_at = #{updatedAt}
             WHERE uuid = #{uuid}::uuid
               AND user_id = #{userId}
               AND is_deleted = FALSE
            """)
    int updateBranchAlias(
            @Param("uuid") UUID uuid,
            @Param("userId") long userId,
            @Param("alias") String alias,
            @Param("updatedAt") long updatedAt);

    /**
     * 批量软删除消息（用于删除整轮对话或编辑时删除 AI 回复）。
     */
    @Update("""
            <script>
            UPDATE chat_messages
               SET is_deleted = TRUE,
                   updated_at = #{updatedAt}
             WHERE uuid IN
               <foreach item="u" collection="uuids" open="(" separator="," close=")">
                 #{u}::uuid
               </foreach>
               AND user_id = #{userId}
            </script>
            """)
    int softDeleteByUuids(
            @Param("uuids") List<UUID> uuids,
            @Param("userId") long userId,
            @Param("updatedAt") long updatedAt);

    /**
     * 软删除指定父消息节点的所有 ASSISTANT 子消息（编辑 USER 消息后清理 AI 回复，单次 SQL）。
     */
    @Update("""
            UPDATE chat_messages
               SET is_deleted = TRUE,
                   updated_at = #{updatedAt}
             WHERE parent_uuid = #{parentUuid}::uuid
               AND user_id = #{userId}
               AND role = 'ASSISTANT'
               AND is_deleted = FALSE
            """)
    int softDeleteAssistantChildren(
            @Param("parentUuid") UUID parentUuid,
            @Param("userId") long userId,
            @Param("updatedAt") long updatedAt);
}
