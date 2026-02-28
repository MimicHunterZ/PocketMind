package com.doublez.pocketmindserver.ai.application;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 聊天 SSE 事件构造器。
 *
 * 统一负责 payload 序列化和标准事件帧构建，避免手写 JSON 与重复样板代码。
 */
@Component
public class ChatSseEventFactory {

    private final ObjectMapper objectMapper;

    public ChatSseEventFactory(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public ServerSentEvent<String> delta(String delta) {
        return ServerSentEvent.<String>builder()
                .event("delta")
                .data(delta)
                .build();
    }

    public ServerSentEvent<String> done(String requestId, UUID messageUuid) {
        return event("done", Map.of(
                "messageUuid", messageUuid.toString(),
                "requestId", requestId
        ));
    }

    public ServerSentEvent<String> paused(String requestId, UUID messageUuid) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("requestId", requestId);
        if (messageUuid != null) {
            payload.put("messageUuid", messageUuid.toString());
        }
        return event("paused", payload);
    }

    public ServerSentEvent<String> error(String message) {
        return event("error", Map.of("message", message));
    }

    public ServerSentEvent<String> titleUpdate(String title) {
        return event("title_update", Map.of("title", title));
    }

    public ServerSentEvent<String> event(String eventName, Map<String, Object> payload) {
        return ServerSentEvent.<String>builder()
                .event(eventName)
                .data(toJson(payload))
                .build();
    }

    private String toJson(Map<String, Object> payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("SSE 负载序列化失败", e);
        }
    }
}
