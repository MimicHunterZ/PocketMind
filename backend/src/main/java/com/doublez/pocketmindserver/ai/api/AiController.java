package com.doublez.pocketmindserver.ai.api;

import com.doublez.pocketmindserver.ai.api.dto.AiImageAnalyzeRequest;
import com.doublez.pocketmindserver.ai.api.dto.AiAnalyzeRequest;
import com.doublez.pocketmindserver.ai.api.dto.AiAnalyzeResponse;
import com.doublez.pocketmindserver.ai.application.AiAnalyzeService;
import com.doublez.pocketmindserver.ai.application.VisionService;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * AI 内容分析接口
 * 功能：接收用户问题和 URL，根据问题决定精准回答或内容总结
 */
@Slf4j
@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class AiController {

    private final AiAnalyzeService aiAnalyzeService;

    private final VisionService visionService;

    /**
     * AI 分析接口
     * 
     * @param request 包含 url 和可选的 userQuestion
     * @return AI 分析结果
     */
    @PostMapping("/analyze")
    public ResponseEntity<AiAnalyzeResponse> analyze(@Valid @RequestBody AiAnalyzeRequest request) {
        String userId = UserContext.getRequiredUserId();
        log.info("收到 AI 分析请求 - uuid: {}, url: {}, hasQuestion: {}",
                userId, request.uuid(), request.userQuestion() != null && !request.userQuestion().isBlank());
        
        AiAnalyzeResponse response = aiAnalyzeService.analyze(request, userId);
        if(response == null){
            throw new BusinessException(ApiCode.AI_RESPONSE_ERROR, HttpStatus.INTERNAL_SERVER_ERROR);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/analyze/image")
    public String analyzeImage(@Valid @RequestBody AiImageAnalyzeRequest request) {
        String userId = UserContext.getRequiredUserId();
        log.info("收到图片识别请求 - userId: {}, path: {}", userId, request.localImagePath());

        String response = visionService.analyzeImage(request.localImagePath());
        if(response == null){
            throw new BusinessException(ApiCode.AI_RESPONSE_ERROR, HttpStatus.INTERNAL_SERVER_ERROR);
        }
        return response;
    }
}
