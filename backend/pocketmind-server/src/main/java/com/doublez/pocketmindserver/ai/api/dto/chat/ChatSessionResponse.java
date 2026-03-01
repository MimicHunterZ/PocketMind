package com.doublez.pocketmindserver.ai.api.dto.chat;

import java.util.UUID;

/**
 * 聊天会话响应体
 */
public record ChatSessionResponse(
        UUID uuid,
        UUID scopeNoteUuid,
        String title,
        long updatedAt
) {
}
