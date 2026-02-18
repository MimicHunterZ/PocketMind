package com.doublez.pocketmindserver.ai.config;

import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * AiProvidersProperties 单元测试。
 */
class AiProvidersPropertiesTest {

    @Test
    void resolveConfig_shouldPreferRoutes() {
        AiProvidersProperties.ProviderConfig deepseek = new AiProvidersProperties.ProviderConfig(
                "k1",
                "https://api.deepseek.com",
                "deepseek-chat",
                131072
        );
        AiProvidersProperties.ProviderConfig dashscope = new AiProvidersProperties.ProviderConfig(
                "k2",
                "https://dashscope.aliyuncs.com/compatible-mode/v1",
                "qwen",
                65536
        );

        AiProvidersProperties props = new AiProvidersProperties(
                new AiProvidersProperties.Routes(
                        "dashscope",
                        "deepseek",
                        "deepseek",
                        "dashscope",
                        null,
                        null,
                        "deepseek",
                        "deepseek"
                ),
                Map.of(
                        "deepseek", deepseek,
                        "dashscope", dashscope
                )
        );

        assertEquals("qwen", props.resolveConfig(AiClientId.CHAT_PRIMARY).model());
        assertEquals("deepseek-chat", props.resolveConfig(AiClientId.CHAT_SECONDARY).model());
        assertEquals("qwen", props.resolveConfig(AiClientId.VISION_PRIMARY).model());
    }

    @Test
    void resolveConfig_shouldThrowWhenRoutesMissing() {
        AiProvidersProperties.ProviderConfig deepseek = new AiProvidersProperties.ProviderConfig(
                "k1",
                "https://api.deepseek.com",
                "deepseek-chat",
                131072
        );
        AiProvidersProperties.ProviderConfig dashscope = new AiProvidersProperties.ProviderConfig(
                "k2",
                "https://dashscope.aliyuncs.com/compatible-mode/v1",
                "qwen",
                65536
        );

        AiProvidersProperties props = new AiProvidersProperties(
                null,
                Map.of(
                        "deepseek", deepseek,
                        "dashscope", dashscope
                )
        );

        assertThrows(RuntimeException.class, () -> props.resolveConfig(AiClientId.CHAT_PRIMARY));
    }

    @Test
    void resolveConfig_shouldThrowWhenMissing() {
                AiProvidersProperties props = new AiProvidersProperties(null, Map.of());

        assertThrows(RuntimeException.class, () -> props.resolveConfig(AiClientId.CHAT_PRIMARY));
    }
}
