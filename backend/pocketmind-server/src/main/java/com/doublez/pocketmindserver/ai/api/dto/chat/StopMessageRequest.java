package com.doublez.pocketmindserver.ai.api.dto.chat;

import jakarta.validation.constraints.NotBlank;

/**
 * 停止流式回复请求体。
 */
public record StopMessageRequest(
        @NotBlank(message = "requestId 不能为空")
        String requestId
) {
}
