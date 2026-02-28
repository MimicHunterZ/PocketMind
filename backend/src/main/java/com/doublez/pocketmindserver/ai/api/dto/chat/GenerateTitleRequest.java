package com.doublez.pocketmindserver.ai.api.dto.chat;

import jakarta.validation.constraints.NotBlank;

/**
 * 生成会话标题请求体。
 */
public record GenerateTitleRequest(
        @NotBlank(message = "content 不能为空")
        String content
) {
}
