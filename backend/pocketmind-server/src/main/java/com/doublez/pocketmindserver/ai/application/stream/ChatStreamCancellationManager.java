package com.doublez.pocketmindserver.ai.application.stream;

import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;
import reactor.core.publisher.Sinks;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 聊天流取消管理器（单机内存级）。
 *
 * 维护 streamKey -> cancelSink 映射，用于外部 stop 请求中断指定流式任务。
 */
@Component
public class ChatStreamCancellationManager {

    private final Map<String, Sinks.One<String>> cancelSinkMap = new ConcurrentHashMap<>();

    public String buildKey(long userId, UUID sessionUuid, String requestId) {
        return userId + ":" + sessionUuid + ":" + requestId;
    }

    public Mono<String> listenCancel(String streamKey) {
        return cancelSinkMap.computeIfAbsent(streamKey, key -> Sinks.one()).asMono();
    }

    public boolean cancel(String streamKey, String reason) {
        Sinks.One<String> sink = cancelSinkMap.get(streamKey);
        if (sink == null) {
            return false;
        }
        Sinks.EmitResult result = sink.tryEmitValue(reason == null ? "cancelled" : reason);
        return result == Sinks.EmitResult.OK || result == Sinks.EmitResult.FAIL_TERMINATED;
    }

    public void cleanup(String streamKey) {
        cancelSinkMap.remove(streamKey);
    }
}
