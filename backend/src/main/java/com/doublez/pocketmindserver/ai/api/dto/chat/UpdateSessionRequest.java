package com.doublez.pocketmindserver.ai.api.dto.chat;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 更新会话请求体（当前仅支持修改标题）
 */
public record UpdateSessionRequest(
        @NotBlank(message = "会话标题不能为空")
        @Size(max = 50, message = "会话标题最多 50 个字符")
        String title
) {
}
