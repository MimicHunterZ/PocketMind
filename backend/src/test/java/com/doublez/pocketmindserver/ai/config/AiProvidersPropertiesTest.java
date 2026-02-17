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
                "deepseek",
                "dashscope",
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

        assertEquals("qwen", props.resolveConfig(AiRole.PRIMARY).model());
        assertEquals("deepseek-chat", props.resolveConfig(AiRole.SECONDARY).model());
        assertEquals("qwen", props.resolveConfig(AiRole.VISION).model());
    }

    @Test
    void resolveConfig_shouldFallbackToActiveChatAndVision() {
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
                "deepseek",
                "dashscope",
                null,
                Map.of(
                        "deepseek", deepseek,
                        "dashscope", dashscope
                )
        );

        assertEquals("deepseek-chat", props.resolveConfig(AiRole.PRIMARY).model());
        assertEquals("deepseek-chat", props.resolveConfig(AiRole.FALLBACK).model());
        assertEquals("qwen", props.resolveConfig(AiRole.VISION).model());
    }

    @Test
    void resolveConfig_shouldThrowWhenMissing() {
        AiProvidersProperties props = new AiProvidersProperties(
                "",
                "",
                null,
                Map.of()
        );

        assertThrows(IllegalStateException.class, () -> props.resolveConfig(AiRole.PRIMARY));
    }
}
