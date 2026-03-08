package com.doublez.pocketmindserver.resource.application;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * ResourceContextService 路径规则测试。
 */
class ResourceContextServiceTest {

    private final ResourceContextService service = new ResourceContextServiceImpl();

    @Test
    void shouldBuildWebClipResourceUri() {
        UUID noteUuid = UUID.randomUUID();
        String actual = service.webClipResource(3L, noteUuid).value();
        assertEquals("pm://users/3/resources/notes/" + noteUuid + "/source/web-clip", actual);
    }

    @Test
    void shouldBuildChatTranscriptUri() {
        UUID sessionUuid = UUID.randomUUID();
        String actual = service.chatTranscriptResource(5L, sessionUuid).value();
        assertEquals("pm://users/5/resources/chats/" + sessionUuid + "/transcript", actual);
    }
}
