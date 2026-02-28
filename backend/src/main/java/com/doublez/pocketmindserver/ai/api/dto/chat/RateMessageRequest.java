package com.doublez.pocketmindserver.ai.api.dto.chat;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

/**
 * 消息评分请求体
 * rating: 1=点赞，0=取消评价，-1=点踩
 */
public record RateMessageRequest(
        @Min(value = -1, message = "评分最小值为 -1")
        @Max(value = 1, message = "评分最大值为 1")
        int rating
) {
}
