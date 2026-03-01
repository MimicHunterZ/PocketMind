package com.doublez.pocketmindserver.demo;

import io.opentelemetry.api.trace.Span;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.*;

import java.util.concurrent.TimeUnit;

@Slf4j
@RestController
@RequestMapping("/demo")
@ConditionalOnProperty(prefix = "pocketmind.demo", name = "enabled", havingValue = "true")
public class SkillController {
    private final ChatClient baselineChatClient;
    private final ChatClient prunedChatClient;

    public SkillController(@Qualifier("skillBaselineChatClient") ChatClient baselineChatClient,
                           @Qualifier("skillPrunedChatClient") ChatClient prunedChatClient) {
        this.baselineChatClient = baselineChatClient;
        this.prunedChatClient = prunedChatClient;
    }

    /**
     * 测试 skill 流程
     * @param message 用户的输入
     * @return
     */
    @PostMapping("/skill")
    public String chat(@RequestBody String message) {
        return runChat(baselineChatClient, message, "raw");
    }

    @PostMapping("/skill/baseline")
    public String chatBaseline(@RequestBody String message) {
        return runChat(baselineChatClient, message, "raw");
    }

    @PostMapping("/skill/pruned")
    public String chatPruned(@RequestBody String message) {
        return runChat(prunedChatClient, message, "pruned");
    }

    private String runChat(ChatClient chatClient, String message, String mode) {
        long startNanos = System.nanoTime();
        String traceId = MDC.get("traceId");
        log.info("Skill 请求开始 - traceId: {}, mode: {}, messageLength: {}", traceId, mode, message == null ? 0 : message.length());

        // Langfuse FAQ：Trace 的 input/output 默认从“根 observation(根 span)”复制。
        // Spring Boot 的 HTTP server span 是 root span，但默认不带 input/output，所以 Langfuse 会显示为空。
        // 这里显式写入 Langfuse 识别的属性：langfuse.trace.input / langfuse.trace.output。
        Span rootSpan = Span.current();
        rootSpan.setAttribute("langfuse.trace.name", "http post /demo/skill/" + mode);
        // 你需要做“上下文评估”，所以这里写入全量原文，不做截断。
        rootSpan.setAttribute("langfuse.trace.input", message == null ? "" : message);
        rootSpan.setAttribute("langfuse.trace.metadata.mode", mode);

        String response = chatClient.prompt()
                .system("当前操作环境 os： windows, 确保相关工具调用符合windows的命令")
                .user(message)
                .call()
                .content();

        // 你需要做“上下文评估”，所以这里写入全量原文，不做截断。
        rootSpan.setAttribute("langfuse.trace.output", response == null ? "" : response);

        long latencyMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);
        log.info("Skill 请求完成 - traceId: {}, mode: {}, latencyMs: {}, responseLength: {}",
            traceId,
            mode,
            latencyMs,
            response == null ? 0 : response.length());
        return response;
    }
}
