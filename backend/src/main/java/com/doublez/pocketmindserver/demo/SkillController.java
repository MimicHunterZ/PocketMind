package com.doublez.pocketmindserver.demo;

import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.web.bind.annotation.*;

import java.util.concurrent.TimeUnit;

@Slf4j
@RestController
@RequestMapping("/demo")
public class SkillController {
    private final ChatClient optimizedChatClient;
    private final ChatClient baselineChatClient;

    public SkillController(@Qualifier("skillOptimizedChatClient") ChatClient optimizedChatClient,
                           @Qualifier("skillBaselineChatClient") ChatClient baselineChatClient) {
        this.optimizedChatClient = optimizedChatClient;
        this.baselineChatClient = baselineChatClient;
    }

    /**
     * 测试 skill 流程
     * @param message 用户的输入
     * @return
     */
    @PostMapping("/skill")
    public String chat(@RequestBody String message) {
        return runChat(optimizedChatClient, message, "optimized");
    }

    @PostMapping("/skill/baseline")
    public String chatBaseline(@RequestBody String message) {
        return runChat(baselineChatClient, message, "baseline");
    }

    @PostMapping("/skill/optimized")
    public String chatOptimized(@RequestBody String message) {
        return runChat(optimizedChatClient, message, "optimized");
    }

    private String runChat(ChatClient chatClient, String message, String mode) {
        long startNanos = System.nanoTime();
        String traceId = MDC.get("traceId");
        log.info("Skill 请求开始 - traceId: {}, mode: {}, messageLength: {}", traceId, mode, message == null ? 0 : message.length());

        String response = chatClient.prompt()
                .system("当前操作环境 os： windows, 确保相关工具调用符合windows的命令")
                .user(message)
                .call()
                .content();

        long latencyMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);
        log.info("Skill 请求完成 - traceId: {}, mode: {}, latencyMs: {}, responseLength: {}",
            traceId,
            mode,
            latencyMs,
            response == null ? 0 : response.length());
        return response;
    }
}
