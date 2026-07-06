package com.doublez.pocketmindserver.ai.application.stream;

import com.doublez.pocketmindserver.agui.AgUiEvent;
import com.doublez.pocketmindserver.agui.AgUiEventEncoder;
import com.fasterxml.jackson.annotation.JsonInclude;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * 聊天场景下 AG-UI 事件的构造入口：把会话/消息/工具调用等聊天业务数据，
 * 转换成 {@link AgUiEvent}，再交给协议层的 {@link AgUiEventEncoder} 编码成 SSE 帧。
 *
 * 事件"长什么样、怎么序列化"是 {@code agui} 包的知识，这里只负责"聊天场景该发哪个事件"。
 */
@Component("streamChatSseEventFactory")
public class ChatSseEventFactory {

    private final AgUiEventEncoder encoder;

    public ChatSseEventFactory(AgUiEventEncoder encoder) {
        this.encoder = encoder;
    }

    public ServerSentEvent<String> encode(AgUiEvent event) {
        return encoder.encode(event);
    }

    public ServerSentEvent<String> runError(String message) {
        return encode(new AgUiEvent.RunError(message));
    }

    /** 用户主动打断生成：AG-UI 词汇里没有对应事件，走 CUSTOM。 */
    public ServerSentEvent<String> paused(String requestId, UUID messageUuid) {
        return encode(pausedEvent(requestId, messageUuid));
    }

    public AgUiEvent pausedEvent(String requestId, UUID messageUuid) {
        return new AgUiEvent.Custom("chat.paused", new PausedPayload(requestId,
                messageUuid == null ? null : messageUuid.toString()));
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    private record PausedPayload(String requestId, String messageUuid) {
    }
}
