package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Answers;
import org.mockito.ArgumentMatchers;
import org.mockito.Mockito;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.io.ByteArrayResource;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.function.Consumer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;


/**
 * VisionService 单元测试。
 */
class VisionServiceTest {

    @TempDir
    Path tempDir;

    @Test
    void analyzeImage_shouldReturnErrorWhenFileMissing() {
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
        VisionService service = new VisionService(
            router,
                new ByteArrayResource("sys".getBytes()),
                new ByteArrayResource("user".getBytes())
        );

        String resp = service.analyzeImage(tempDir.resolve("missing.png").toString());
        assertTrue(resp.contains("文件不存在"));
        Mockito.verify(vision, Mockito.never()).prompt();
    }

    @Test
    void analyzeImage_shouldCallChatClientAndReturnContent() throws Exception {
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

        // 明确匹配 Consumer 重载，避免与 system(Resource)/user(Resource) 冲突。
        Mockito.when(vision.prompt()
            .system(ArgumentMatchers.<Consumer<ChatClient.PromptSystemSpec>>any())
            .user(ArgumentMatchers.<Consumer<ChatClient.PromptUserSpec>>any())
            .call()
            .content())
                .thenReturn("OK");

        // 深度 stub 的 when(...) 会触发一次 prompt() 调用；这里清理掉，避免影响后续 verify。
        Mockito.clearInvocations(vision);

        VisionService service = new VisionService(
            router,
                new ByteArrayResource("system-prompt".getBytes()),
                new ByteArrayResource("user-prompt".getBytes())
        );

        Path img = tempDir.resolve("img.png");
        Files.write(img, new byte[]{0x1, 0x2, 0x3});

        String resp = service.analyzeImage(img.toString());
        assertEquals("OK", resp);
        Mockito.verify(vision, Mockito.times(1)).prompt();
    }
}
