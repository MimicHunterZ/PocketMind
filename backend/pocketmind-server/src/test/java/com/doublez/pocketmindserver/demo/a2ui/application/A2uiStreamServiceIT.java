package com.doublez.pocketmindserver.demo.a2ui.application;

import com.doublez.pocketmindserver.ai.application.stream.ChatSseEventFactory;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.codec.ServerSentEvent;
import reactor.core.publisher.Flux;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * A2UI 真实链路约束测试（无 mock）。
 */
class A2uiStreamServiceIT {

    private static final class FakeAiFailoverRouter extends AiFailoverRouter {
        FakeAiFailoverRouter() {
            super(
                    (ChatClient) null,
                    (ChatClient) null,
                    null,
                    null,
                    null,
                    null
            );
        }

        @Override
        public Flux<String> executeChatStream(String purpose, java.util.function.Function<ChatClient, Flux<String>> call) {
            return Flux.just("# 真实A2UI输出\n", "\n按问题生成执行计划。\n");
        }
    }

    @Test
    void streamShouldNotContainDemoHardcodedPayload() {
        A2uiStreamService service = new A2uiStreamServiceImpl(
                new ChatSseEventFactory(new ObjectMapper()),
                new FakeAiFailoverRouter(),
                new ClassPathResource("prompts/demo/a2ui/option_c_stream_system.md"),
                new ClassPathResource("prompts/demo/a2ui/option_c_stream_user.md")
        );

        List<ServerSentEvent<String>> events = service.stream(
                100L,
                "请基于真实上下文规划同步方案",
                "req-it-1"
        ).collectList().block();

        assertNotNull(events);
        String allData = events.stream()
                .map(ServerSentEvent::data)
                .filter(v -> v != null && !v.isBlank())
                .reduce("", (a, b) -> a + "\n" + b);

        assertFalse(allData.contains("PocketMind Team"));
        assertFalse(allData.contains("T-101"));
        assertFalse(allData.contains("A2UI_STREAM_FAILED"));
        assertTrue(allData.contains("用户问题：请基于真实上下文规划同步方案"));
    }
}
