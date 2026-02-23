package com.doublez.pocketmindserver.ai.api.dto.chat;

import java.util.UUID;

/**
 * 创建聊天会话请求体
 */
public record CreateSessionRequest(
        //关联的笔记 UUID（可选，null 表示全局对话）
        UUID noteUuid,
        // 会话标题（可选）
        String title
) {
}
