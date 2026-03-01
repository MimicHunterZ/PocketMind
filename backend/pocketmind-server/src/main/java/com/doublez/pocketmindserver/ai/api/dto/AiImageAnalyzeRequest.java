package com.doublez.pocketmindserver.ai.api.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 图片识别请求。
 */
public record AiImageAnalyzeRequest(
        @NotBlank(message = "localImagePath 不能为空")
        String localImagePath
) {
}
