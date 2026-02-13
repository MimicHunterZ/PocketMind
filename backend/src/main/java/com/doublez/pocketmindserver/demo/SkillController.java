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
    private final ChatClient chatClient;

    public SkillController(@Qualifier("skillDemoChatClient") ChatClient chatClient) {
        this.chatClient = chatClient;
    }

    /**
     * 测试 skill 流程
     * @param message 用户的输入
     * @return
     */
    @PostMapping("/skill")
    public String chat(@RequestBody String message) {
        long startNanos = System.nanoTime();
        String traceId = MDC.get("traceId");
        log.info("Skill 请求开始 - traceId: {}, messageLength: {}", traceId, message == null ? 0 : message.length());

        String response = chatClient.prompt()
                .system("当前操作环境 os： windows, 确保相关工具调用符合windows的命令")
                .user(message)
                .call()
                .content();

        long latencyMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);
        log.info("Skill 请求完成 - traceId: {}, latencyMs: {}, responseLength: {}",
            traceId,
            latencyMs,
            response == null ? 0 : response.length());
        return response;
    }
}
