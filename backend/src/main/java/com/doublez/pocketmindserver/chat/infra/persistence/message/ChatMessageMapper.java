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
}
