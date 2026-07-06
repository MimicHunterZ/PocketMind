package com.doublez.pocketmindserver.agui;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Component;

/**
 * 把 {@link AgUiEvent} 编码成 SSE 帧，纯协议层工具，不知道调用方是聊天还是别的场景。
 */
@Component
public final class AgUiEventEncoder {

    private final ObjectMapper objectMapper;

    public AgUiEventEncoder(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public ServerSentEvent<String> encode(AgUiEvent event) {
        return ServerSentEvent.<String>builder()
                .event(event.type())
                .data(toJson(event.toJson()))
                .build();
    }

    private String toJson(Object payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("AG-UI 事件序列化失败", e);
        }
    }
}
