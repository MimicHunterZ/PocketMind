package com.doublez.pocketmindserver.ai.application;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Component;
import reactor.core.Scannable;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Sinks;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SSE 控制事件汇聚管理器（单机内存级）。
 *
 * 负责维护 chatId -> Sinks.Many 映射，并提供标题旁路事件的推送与订阅能力。
 */
@Slf4j
@Component
public class SseEventSinkManager {

    private final ChatSseEventFactory chatSseEventFactory;

    private final Map<String, Sinks.Many<ServerSentEvent<String>>> sinkMap =
            new ConcurrentHashMap<>();

    public SseEventSinkManager(ChatSseEventFactory chatSseEventFactory) {
        this.chatSseEventFactory = chatSseEventFactory;
    }

    /**
     * 监听指定 chatId 的控制帧流。
     */
    public Flux<ServerSentEvent<String>> listen(String chatId) {
        Sinks.Many<ServerSentEvent<String>> sink = sinkMap.computeIfAbsent(
                chatId,
                key -> Sinks.many().multicast().onBackpressureBuffer()
        );
        return sink.asFlux();
    }

    /**
     * 检查指定 chatId 的 Sink 是否仍处于可用状态。
     */
    public boolean isSinkActive(String chatId) {
        Sinks.Many<ServerSentEvent<String>> sink = sinkMap.get(chatId);
        if (sink == null) {
            return false;
        }
        Boolean terminated = sink.scan(Scannable.Attr.TERMINATED);
        return !Boolean.TRUE.equals(terminated);
    }

    /**
     * 推送标题更新控制帧。
     */
    public void pushTitleEvent(String chatId, String title) {
        if (title == null || title.isBlank()) {
            return;
        }
        Sinks.Many<ServerSentEvent<String>> sink = sinkMap.get(chatId);
        if (sink == null) {
            return;
        }

        Sinks.EmitResult emitResult = sink.tryEmitNext(
                chatSseEventFactory.titleUpdate(title)
        );

        if (emitResult.isFailure()) {
            log.debug("推送标题控制帧失败: chatId={}, result={}", chatId, emitResult);
        }
    }

    /**
     * 清理指定 chatId 的资源。
     */
    public void cleanup(String chatId) {
        Sinks.Many<ServerSentEvent<String>> sink = sinkMap.remove(chatId);
        if (sink != null) {
            sink.tryEmitComplete();
        }
    }
}
