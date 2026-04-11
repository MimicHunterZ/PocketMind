package com.doublez.pocketmindserver.demo.a2ui.application;

import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * A2UI Prompt 资源加载与渲染测试。
 */
class A2uiPromptLoadingIT {

    @Test
    void shouldLoadAndRenderA2uiPromptTemplates() throws Exception {
        ClassPathResource streamSystem = new ClassPathResource("prompts/demo/a2ui/option_c_stream_system.md");
        ClassPathResource streamUser = new ClassPathResource("prompts/demo/a2ui/option_c_stream_user.md");

        assertTrue(streamSystem.exists());
        assertTrue(streamUser.exists());

        String renderedUser = PromptBuilder.render(streamUser, Map.of(
                "query", "如何实现A2UI交错流",
                "requestId", "req-prompt"
        ));

        assertTrue(renderedUser.contains("如何实现A2UI交错流"));
        assertTrue(renderedUser.contains("req-prompt"));
    }
}
