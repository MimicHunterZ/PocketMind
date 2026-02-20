package com.doublez.pocketmindserver.ai.api.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

/**
 * AI 分析受理请求（轮询模式）。
 * <p>
 * 必填：url, uuid（v7 业务主键）。
 * 可选：previewTitle / previewContent（或 previewDescribe） / userQuestion。
 */
public record AiAnalyseAcceptRequest(
        @NotNull(message = "uuid 不能为空")
        UUID uuid,
        @NotBlank(message = "url 不能为空")
        String url,
        String previewTitle,
        String previewDescription,
        @JsonAlias({"previewDescribe"})
        String previewContent,
        String userQuestion
) {
    public boolean hasPreviewContent() {
        return previewContent != null && !previewContent.isBlank();
    }

    public boolean hasUserQuestion() {
        return userQuestion != null && !userQuestion.isBlank();
    }
}
