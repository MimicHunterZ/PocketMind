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
 * ChatClient 涓?>鍓?>鍏滃簳 鑷姩闄嶇骇璺敱鍣ㄣ€?
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
     * 鏂囨湰/閫氱敤瀵硅瘽锛歱rimary -> secondary -> fallback锛堝悓姝?闈炴祦寮忓満鏅級銆?
     */
    public <T> T executeChat(String purpose, Function<ChatClient, T> call) {
        return execute(purpose, buildChatClientChain(), call);
    }

    /**
     * 鏂囨湰瀵硅瘽锛堝搷搴斿紡娴佺増鏈級锛歱rimary -> secondary -> fallback銆?
     * <p>
     * 涓庡悓姝ョ増鏈殑鍖哄埆锛歿@link ChatClient} 鐨?stream() 杩斿洖鎯版€?{@link Flux}锛?
     * 鍦ㄨ闃呬箣鍓嶄笉浼氬彂璧风綉缁滆姹傦紝鍥犳鍚屾 try/catch 鏃犳硶鎹曡幏娴佸唴閿欒銆?
     * 姝ゆ柟娉曚娇鐢?Reactor 鐨?{@code onErrorResume} 杩涜閾惧紡闄嶇骇锛?
     * 浠呭綋璁㈤槄鏃剁湡姝ｅ嚭閿欙紝鎵嶈Е鍙戜笅涓€涓鎴风閲嶈瘯銆?
     * </p>
     */
    public Flux<String> executeChatStream(String purpose, Function<ChatClient, Flux<String>> call) {
        List<ChatClient> clients = buildChatClientChain();
        Flux<String> chain = call.apply(clients.get(0));
        for (int i = 1; i < clients.size(); i++) {
            final int tier = i;
            final ChatClient next = clients.get(i);
            chain = chain.onErrorResume(e -> {
                log.warn("AI 娴佸紡璋冪敤澶辫触锛岄檷绾ц嚦绗?{} 灞?- purpose: {}, error: {}",
                        tier, purpose, e.getClass().getSimpleName());
                return call.apply(next);
            });
        }
        return chain;
    }

    /** 鎸夐厤缃瀯寤?chat 闄嶇骇閾撅紙primary -> secondary? -> fallback?锛夈€?*/
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
     * 瑙嗚鐞嗚В锛歷ision-primary -> vision-secondary -> vision-fallback锛坴ision-fallback 鍙€夛級銆?
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

        // 鏈厤缃?vision-secondary 鏃朵笉鍋氶檷绾э紙閬垮厤闅愬紡钀藉埌 chat 閾捐矾锛夈€?
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
                log.warn("AI 璋冪敤澶辫触锛屽噯澶囬檷绾?- purpose: {}, tier: {}, error: {}",
                        purpose, tier, e.getClass().getSimpleName());
            }
        }

        if (last != null) {
            BusinessException ex = new BusinessException(
                    ApiCode.AI_RESPONSE_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "AI 璋冪敤澶辫触锛歱urpose=" + purpose + ", lastError=" + last.getClass().getSimpleName()
            );
            ex.initCause(last);
            throw ex;
        }
        throw new BusinessException(ApiCode.AI_RESPONSE_ERROR, HttpStatus.INTERNAL_SERVER_ERROR,
                "AI 璋冪敤澶辫触锛氭湭鎵惧埌鍙敤鐨?ChatClient - purpose=" + purpose);
    }
}

