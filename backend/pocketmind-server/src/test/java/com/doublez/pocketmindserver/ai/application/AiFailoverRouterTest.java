package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import org.junit.jupiter.api.Test;
import org.mockito.Answers;
import org.mockito.Mockito;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.ObjectProvider;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * AiFailoverRouter 单元测试。
 */
class AiFailoverRouterTest {

    @Test
    void executeChat_shouldFallbackToSecondaryWhenPrimaryFails() {
        ChatClient primary = Mockito.mock(ChatClient.class, Answers.RETURNS_DEEP_STUBS);
        ChatClient secondary = Mockito.mock(ChatClient.class, Answers.RETURNS_DEEP_STUBS);
        ChatClient fallback = Mockito.mock(ChatClient.class, Answers.RETURNS_DEEP_STUBS);
        ChatClient vision = Mockito.mock(ChatClient.class, Answers.RETURNS_DEEP_STUBS);

        @SuppressWarnings("unchecked")
        ObjectProvider<ChatClient> chatSecondaryProvider = Mockito.mock(ObjectProvider.class);
        ObjectProvider<ChatClient> chatFallbackProvider = Mockito.mock(ObjectProvider.class);
        ObjectProvider<ChatClient> visionSecondaryProvider = Mockito.mock(ObjectProvider.class);
        ObjectProvider<ChatClient> visionFallbackProvider = Mockito.mock(ObjectProvider.class);

        Mockito.when(chatSecondaryProvider.getIfAvailable()).thenReturn(secondary);
        Mockito.when(chatFallbackProvider.getIfAvailable()).thenReturn(fallback);
        Mockito.when(visionSecondaryProvider.getIfAvailable()).thenReturn(null);
        Mockito.when(visionFallbackProvider.getIfAvailable()).thenReturn(null);

        AiFailoverRouter router = new AiFailoverRouter(primary, vision, chatSecondaryProvider, chatFallbackProvider, visionSecondaryProvider, visionFallbackProvider);

        Mockito.when(primary.prompt(Mockito.anyString()).call().content())
                .thenThrow(new RuntimeException("boom"));
        Mockito.when(secondary.prompt(Mockito.anyString()).call().content())
                .thenReturn("OK");

        // 深度 stub 的 when(...) 会触发一次 prompt() 调用；这里清理掉，避免影响后续 verify。
        Mockito.clearInvocations(primary, secondary, fallback);

        String result = router.executeChat("t", c -> c.prompt("hi").call().content());
        assertEquals("OK", result);

        Mockito.verify(primary, Mockito.times(1)).prompt(Mockito.anyString());
        Mockito.verify(secondary, Mockito.times(1)).prompt(Mockito.anyString());
        Mockito.verify(fallback, Mockito.never()).prompt(Mockito.anyString());
    }
}
