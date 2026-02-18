package com.doublez.pocketmindserver.ai.config;

import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.function.Function;

/**
 * ChatClient 主->副->兜底 自动降级路由器。
 */
@Slf4j
@Component
public class AiFailoverRouter {

    private final ChatClient chatPrimaryChatClient;
    private final ChatClient visionPrimaryChatClient;

    private final ObjectProvider<ChatClient> chatSecondaryChatClientProvider;
    private final ObjectProvider<ChatClient> chatFallbackChatClientProvider;

    private final ObjectProvider<ChatClient> visionSecondaryChatClientProvider;
    private final ObjectProvider<ChatClient> visionFallbackChatClientProvider;

    public AiFailoverRouter(
            @Qualifier(AiBeanNames.CHAT_PRIMARY_CLIENT) ChatClient chatPrimaryChatClient,
            @Qualifier(AiBeanNames.VISION_PRIMARY_CLIENT) ChatClient visionPrimaryChatClient,
            @Qualifier(AiBeanNames.CHAT_SECONDARY_CLIENT) ObjectProvider<ChatClient> chatSecondaryChatClientProvider,
            @Qualifier(AiBeanNames.CHAT_FALLBACK_CLIENT) ObjectProvider<ChatClient> chatFallbackChatClientProvider,
            @Qualifier(AiBeanNames.VISION_SECONDARY_CLIENT) ObjectProvider<ChatClient> visionSecondaryChatClientProvider,
            @Qualifier(AiBeanNames.VISION_FALLBACK_CLIENT) ObjectProvider<ChatClient> visionFallbackChatClientProvider
    ) {
        this.chatPrimaryChatClient = chatPrimaryChatClient;
        this.visionPrimaryChatClient = visionPrimaryChatClient;
        this.chatSecondaryChatClientProvider = chatSecondaryChatClientProvider;
        this.chatFallbackChatClientProvider = chatFallbackChatClientProvider;
        this.visionSecondaryChatClientProvider = visionSecondaryChatClientProvider;
        this.visionFallbackChatClientProvider = visionFallbackChatClientProvider;
    }

    /**
     * 文本/通用对话：primary -> secondary -> fallback。
     */
    public <T> T executeChat(String purpose, Function<ChatClient, T> call) {
        ChatClient secondary = chatSecondaryChatClientProvider == null ? null : chatSecondaryChatClientProvider.getIfAvailable();
        ChatClient fallback = chatFallbackChatClientProvider == null ? null : chatFallbackChatClientProvider.getIfAvailable();

        if (secondary != null) {
            if (fallback != null) {
                return execute(purpose, List.of(chatPrimaryChatClient, secondary, fallback), call);
            }
            return execute(purpose, List.of(chatPrimaryChatClient, secondary), call);
        }
        return execute(purpose, List.of(chatPrimaryChatClient), call);
    }

    /**
     * 视觉理解：vision-primary -> vision-secondary -> vision-fallback（vision-fallback 可选）。
     */
    public <T> T executeVision(String purpose, Function<ChatClient, T> call) {
        ChatClient visionSecondary = visionSecondaryChatClientProvider == null ? null : visionSecondaryChatClientProvider.getIfAvailable();
        ChatClient visionFallback = visionFallbackChatClientProvider == null ? null : visionFallbackChatClientProvider.getIfAvailable();
        if (visionSecondary != null) {
            if (visionFallback != null) {
                return execute(purpose, List.of(visionPrimaryChatClient, visionSecondary, visionFallback), call);
            }
            return execute(purpose, List.of(visionPrimaryChatClient, visionSecondary), call);
        }

        // 未配置 vision-secondary 时不做降级（避免隐式落到 chat 链路）。
        return execute(purpose, List.of(visionPrimaryChatClient), call);
    }

    private <T> T execute(String purpose, List<ChatClient> clients, Function<ChatClient, T> call) {
        RuntimeException last = null;
        for (int i = 0; i < clients.size(); i++) {
            ChatClient client = clients.get(i);
            String tier = i == 0 ? "primary" : (i == 1 ? "secondary" : "fallback");
            try {
                return call.apply(client);
            } catch (RuntimeException e) {
                last = e;
                log.warn("AI 调用失败，准备降级 - purpose: {}, tier: {}, error: {}",
                        purpose, tier, e.getClass().getSimpleName());
            }
        }

        if (last != null) {
            BusinessException ex = new BusinessException(
                    ApiCode.AI_RESPONSE_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "AI 调用失败：purpose=" + purpose + ", lastError=" + last.getClass().getSimpleName()
            );
            ex.initCause(last);
            throw ex;
        }
        throw new BusinessException(ApiCode.AI_RESPONSE_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                "AI 调用失败：未找到可用的 ChatClient - purpose=" + purpose);
    }
}
