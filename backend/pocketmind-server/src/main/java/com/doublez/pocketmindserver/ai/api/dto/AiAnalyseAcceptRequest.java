package com.doublez.pocketmindserver.ai.api.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.List;
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
        // 帖子的title
        String previewTitle,
        // 帖子的内容：content（或 description）
        String previewDescription,
        String previewContent,
        String userQuestion,
        // 用户记录的title
        String title,
        // 用户记录的content
        String content
) {
    public boolean hasPreviewContent() {
        return (previewContent != null && !previewContent.isBlank()) || (previewDescription != null && !previewDescription.isBlank());
    }

    public boolean hasUserQuestion() {
        return userQuestion != null && !userQuestion.isBlank();
    }
}
