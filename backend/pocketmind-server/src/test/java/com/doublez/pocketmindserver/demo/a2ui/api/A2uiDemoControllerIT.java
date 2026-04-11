package com.doublez.pocketmindserver.demo.a2ui.api;

import com.doublez.pocketmindserver.ai.application.stream.ChatSseEventFactory;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.demo.a2ui.api.dto.A2uiStreamRequest;
import com.doublez.pocketmindserver.demo.a2ui.application.A2uiStreamService;
import com.doublez.pocketmindserver.demo.a2ui.application.A2uiStreamServiceImpl;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.codec.ServerSentEvent;
import reactor.core.publisher.Flux;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;

/**
 * A2UI Demo Controller 端点真实协议约束测试（无 mock）。
 */
class A2uiDemoControllerIT {

    private static final class FakeAiFailoverRouter extends AiFailoverRouter {
        FakeAiFailoverRouter() {
            super((ChatClient) null, (ChatClient) null, null, null, null, null);
        }

        @Override
        public Flux<String> executeChatStream(String purpose, java.util.function.Function<ChatClient, Flux<String>> call) {
            return Flux.just("# 控制器链路\n", "\n实时增量内容\n");
        }
    }

    @AfterEach
    void tearDown() {
        UserContext.clear();
    }

    @Test
    void streamShouldNotReturnDemoHardcodedPayload() {
        A2uiStreamService service = new A2uiStreamServiceImpl(
                new ChatSseEventFactory(new ObjectMapper()),
                new FakeAiFailoverRouter(),
                new ClassPathResource("prompts/demo/a2ui/option_c_stream_system.md"),
                new ClassPathResource("prompts/demo/a2ui/option_c_stream_user.md")
        );
        A2uiDemoController controller = new A2uiDemoController(service);

        UserContext.setUserId("100");
        Flux<ServerSentEvent<String>> flux = controller.stream(
                "req-it-2",
                new A2uiStreamRequest("请给出真实A2UI流式输出")
        );

        List<ServerSentEvent<String>> events = flux.collectList().block();
        assertNotNull(events);

        String allData = events.stream()
                .map(ServerSentEvent::data)
                .filter(v -> v != null && !v.isBlank())
                .reduce("", (a, b) -> a + "\n" + b);

        assertFalse(allData.contains("PocketMind Team"));
        assertFalse(allData.contains("T-101"));
    }
}
