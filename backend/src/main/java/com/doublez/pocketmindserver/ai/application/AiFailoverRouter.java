package com.doublez.pocketmindserver.ai.application;

import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.function.Function;

/**
 * ChatClient 主->副->兜底 自动降级路由器。
 */
@Slf4j
@Component
public class AiFailoverRouter {

    private final ChatClient primaryChatClient;
    private final ChatClient secondaryChatClient;
    private final ChatClient fallbackChatClient;
    private final ChatClient visionChatClient;

    private final ObjectProvider<ChatClient> visionSecondaryChatClientProvider;
    private final ObjectProvider<ChatClient> visionFallbackChatClientProvider;

    public AiFailoverRouter(
            @Qualifier("primaryChatClient") ChatClient primaryChatClient,
            @Qualifier("secondaryChatClient") ChatClient secondaryChatClient,
            @Qualifier("fallbackChatClient") ChatClient fallbackChatClient,
            @Qualifier("visionChatClient") ChatClient visionChatClient,
            @Qualifier("visionSecondaryChatClient") ObjectProvider<ChatClient> visionSecondaryChatClientProvider,
            @Qualifier("visionFallbackChatClient") ObjectProvider<ChatClient> visionFallbackChatClientProvider
    ) {
        this.primaryChatClient = primaryChatClient;
        this.secondaryChatClient = secondaryChatClient;
        this.fallbackChatClient = fallbackChatClient;
        this.visionChatClient = visionChatClient;
        this.visionSecondaryChatClientProvider = visionSecondaryChatClientProvider;
        this.visionFallbackChatClientProvider = visionFallbackChatClientProvider;
    }

    /**
     * 文本/通用对话：primary -> secondary -> fallback。
     */
    public <T> T executeChat(String purpose, Function<ChatClient, T> call) {
        return execute(purpose, List.of(primaryChatClient, secondaryChatClient, fallbackChatClient), call);
    }

    /**
     * 视觉理解：vision -> secondary -> fallback。
     * 说明：如果 secondary/fallback 不支持 vision，请在 routes 中把它们也指向支持 vision 的 provider。
     */
    public <T> T executeVision(String purpose, Function<ChatClient, T> call) {
        ChatClient visionSecondary = visionSecondaryChatClientProvider == null ? null : visionSecondaryChatClientProvider.getIfAvailable();
        ChatClient visionFallback = visionFallbackChatClientProvider == null ? null : visionFallbackChatClientProvider.getIfAvailable();

        if (visionSecondary != null && visionFallback != null) {
            return execute(purpose, List.of(visionChatClient, visionSecondary, visionFallback), call);
        }
        if (visionSecondary != null) {
            return execute(purpose, List.of(visionChatClient, visionSecondary, fallbackChatClient), call);
        }
        if (visionFallback != null) {
            return execute(purpose, List.of(visionChatClient, visionFallback), call);
        }

        return execute(purpose, List.of(visionChatClient, secondaryChatClient, fallbackChatClient), call);
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
            throw last;
        }
        throw new IllegalStateException("AI 调用失败：未找到可用的 ChatClient - purpose=" + purpose);
    }
}
