package com.doublez.pocketmindserver.ai.config;

import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import reactor.core.publisher.Flux;

import java.util.List;
import java.util.function.Function;

/**
 * ChatClient 主/次/兜底自动降级路由器。
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
        * 文本/通用对话：primary -> secondary -> fallback（同步、非流式场景）。
     */
    public <T> T executeChat(String purpose, Function<ChatClient, T> call) {
        return execute(purpose, buildChatClientChain(), call);
    }

    /**
        * 文本对话（响应式流版本）：primary -> secondary -> fallback。
     * <p>
        * 与同步版本不同，{@link ChatClient} 的 stream() 返回惰性 {@link Flux}。
        * 在订阅前不会发起网络请求，因此同步 try/catch 无法捕获流内错误。
        * 此方法使用 Reactor 的 {@code onErrorResume} 进行链式降级，
        * 仅在订阅阶段真实出错时才切换到下一个客户端。
     * </p>
     */
    public Flux<String> executeChatStream(String purpose, Function<ChatClient, Flux<String>> call) {
        List<ChatClient> clients = buildChatClientChain();
        Flux<String> chain = call.apply(clients.get(0));
        for (int i = 1; i < clients.size(); i++) {
            final int tier = i;
            final ChatClient next = clients.get(i);
            chain = chain.onErrorResume(e -> {
                log.warn("AI 流式调用失败，降级到第 {} 层，purpose={}, error={}",
                        tier, purpose, e.getClass().getSimpleName());
                return call.apply(next);
            });
        }
        return chain;
    }

    /** 按配置构建 chat 降级链（primary -> secondary -> fallback）。 */
    private List<ChatClient> buildChatClientChain() {
        List<ChatClient> list = new java.util.ArrayList<>();
        list.add(chatPrimaryChatClient);
        ChatClient secondary = chatSecondaryChatClientProvider.getIfAvailable();
        if (secondary != null) list.add(secondary);
        ChatClient fallback = chatFallbackChatClientProvider.getIfAvailable();
        if (fallback != null) list.add(fallback);
        return list;
    }

    /**
     * 视觉理解：vision-primary -> vision-secondary -> vision-fallback（fallback 可选）。
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

        // 未配置 vision-secondary 时不降级，避免隐式落到 chat 链路。
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
                log.warn("AI 调用失败，准备降级，purpose={}, tier={}, error={}",
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
            "AI 调用失败：未找到可用 ChatClient，purpose=" + purpose);
    }
}

