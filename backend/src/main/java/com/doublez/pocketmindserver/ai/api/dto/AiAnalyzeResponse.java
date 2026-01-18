package com.doublez.pocketmindserver.ai.api.dto;

/**
 * AI 分析响应 DTO
 *
 * @param mode          分析模式：QA（问答）或 SUMMARY（总结）
 * @param userQuestion  用户问题（问答模式下有值）
 * @param aiResponse    AI 回复内容
 */
public record AiAnalyzeResponse<T>(
        String mode,
        String userQuestion,
        T aiResponse
) {
}
