package com.doublez.pocketmindserver.ai.api;

import com.doublez.pocketmindserver.ai.api.dto.AiAnalyseAcceptRequest;
import com.doublez.pocketmindserver.ai.api.dto.AiAnalyseAcceptResponse;
import com.doublez.pocketmindserver.ai.application.AiAnalysePollingService;
import com.doublez.pocketmindserver.shared.security.UserContext;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * AI 内容分析接口。
 * 功能：接收用户问题和 URL，根据问题决定精准回答或内容总结。
 */
@Slf4j
@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class AiController {

    private final AiAnalysePollingService aiAnalysePollingService;

    /**
     * AI 分析（轮询模式）：立即返回 202 Accepted，客户端轮询。
     */
    @PostMapping(value = "/analyze", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<AiAnalyseAcceptResponse> analyze(@Valid @RequestBody AiAnalyseAcceptRequest request) {
        String userId = UserContext.getRequiredUserId();
        log.info("收到 AI 分析受理请求 - userId: {}, uuid: {}, url: {}, hasPreview: {}, hasQuestion: {}",
                userId, request.uuid(), request.url(), request.hasPreviewContent(), request.hasUserQuestion());

        aiAnalysePollingService.accept(userId, request);
        return ResponseEntity.accepted().body(new AiAnalyseAcceptResponse(request.uuid(), request.url()));
    }

}
