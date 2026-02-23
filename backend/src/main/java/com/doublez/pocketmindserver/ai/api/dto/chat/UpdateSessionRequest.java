package com.doublez.pocketmindserver.ai.api.dto.chat;

/**
 * 更新会话请求体（当前仅支持修改标题）
 */
public record UpdateSessionRequest(String title) {
}
