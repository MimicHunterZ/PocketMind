package com.doublez.pocketmindserver.demo.a2ui.application;

import org.springframework.http.codec.ServerSentEvent;
import reactor.core.publisher.Flux;

/**
 * A2UI 专用流式服务。
 */
public interface A2uiStreamService {

    Flux<ServerSentEvent<String>> stream(long userId,
                                         String query,
                                         String requestId);
}
