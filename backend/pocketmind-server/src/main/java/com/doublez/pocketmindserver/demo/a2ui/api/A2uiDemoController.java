package com.doublez.pocketmindserver.demo.a2ui.api;

import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import com.doublez.pocketmindserver.demo.a2ui.api.dto.A2uiStreamRequest;
import com.doublez.pocketmindserver.demo.a2ui.application.A2uiStreamService;
import com.doublez.pocketmindserver.shared.security.UserContext;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Flux;

import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/demo/a2ui")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class A2uiDemoController {

    private final A2uiStreamService a2uiStreamService;

    @PostMapping(
            value = "/stream",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.TEXT_EVENT_STREAM_VALUE
    )
    public Flux<ServerSentEvent<String>> stream(
            @RequestHeader(name = "X-Request-Id", required = false) String requestId,
            @Valid @RequestBody A2uiStreamRequest request
    ) {
        long userId = parseUserId();
        String effectiveRequestId = requestId != null && !requestId.isBlank()
                ? requestId
                : UUID.randomUUID().toString();
        log.info("收到 A2UI Demo 流式请求: userId={}, requestId={}, queryLength={}",
                userId, effectiveRequestId, request.query().length());
        return a2uiStreamService.stream(userId, request.query(), effectiveRequestId);
    }

    private long parseUserId() {
        String raw = UserContext.getRequiredUserId();
        try {
            return Long.parseLong(raw);
        } catch (NumberFormatException ex) {
            throw new BusinessException(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "userId=" + raw);
        }
    }
}
