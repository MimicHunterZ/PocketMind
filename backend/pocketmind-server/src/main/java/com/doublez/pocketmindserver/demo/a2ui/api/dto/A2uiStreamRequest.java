package com.doublez.pocketmindserver.demo.a2ui.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * A2UI 流式请求体。
 */
public record A2uiStreamRequest(
        @NotBlank(message = "query 不能为空")
        @Size(max = 20000, message = "query 最多 20000 字符")
        String query
) {
}
