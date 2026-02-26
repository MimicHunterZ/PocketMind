package com.doublez.pocketmindserver.ai.api.dto.chat;

import jakarta.validation.constraints.NotBlank;

/**
 * 编辑消息请求体（仅支持 USER 消息）
 */
public record EditMessageRequest(
        @NotBlank(message = "消息内容不能为空")
        String content
) {
}
