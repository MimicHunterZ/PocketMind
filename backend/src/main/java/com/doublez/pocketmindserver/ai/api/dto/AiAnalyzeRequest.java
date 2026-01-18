package com.doublez.pocketmindserver.ai.api.dto;

import jakarta.validation.constraints.NotBlank;


public record AiAnalyzeRequest(
        @NotBlank(message = "uuid 不能为空")
        String uuid,

        String title,

        @NotBlank(message = "content 不能为空")
        String content,
        
        String userQuestion
) {
    /**
     * 判断是否为问答模式
     */
    public boolean isQaMode() {
        return userQuestion != null && !userQuestion.isBlank();
    }
}
