package com.doublez.pocketmindserver.ai.api.dto.chat;

/**
 * 消息评分请求体
 * rating: 1=点赞，0=取消评价，-1=点踩
 */
public record RateMessageRequest(int rating) {
}
