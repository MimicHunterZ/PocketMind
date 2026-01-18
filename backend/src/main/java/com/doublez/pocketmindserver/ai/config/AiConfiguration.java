package com.doublez.pocketmindserver.ai.config;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * AI 模块配置
 * 配置 ChatClient Bean 用于 AI 服务
 */
@Configuration
public class AiConfiguration {

    /**
     * 创建 OpenAI ChatClient
     * 使用 Spring AI 自动配置的 OpenAiChatModel
     */
    @Bean
    public ChatClient openAiChatClient(OpenAiChatModel chatModel) {
        return ChatClient.builder(chatModel)
                .build();
    }
}
