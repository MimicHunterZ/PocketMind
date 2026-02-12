package com.doublez.pocketmindserver.shared.web;

import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.stream.Collectors;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    // 仅用于控制台日志打印策略：dev模式打印完整堆栈，prod模式只打印摘要
    @Value("${app.exception.show-stacktrace:false}")
    private boolean showStacktrace;

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Object>> handleBusiness(BusinessException e) {
        // 在控制台打印日志
        handleLogging(e);

        String traceId = TraceIdContext.currentTraceId();
        // 恢复原有逻辑：返回业务详情，不带堆栈
        return ResponseEntity.status(e.getStatus())
                .body(ApiResponse.error(e.getCode(), e.getDetail(), traceId));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Object>> handleValidation(MethodArgumentNotValidException e) {
        // 在控制台打印日志
        handleLogging(e);

        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .filter(m -> m != null && !m.isBlank())
                .collect(Collectors.joining("; "));
        String traceId = TraceIdContext.currentTraceId();

        // message 走统一映射，具体校验原因放到 data
        Object data = message.isBlank() ? null : message;
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(ApiCode.REQ_VALIDATION, data, traceId));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiResponse<Object>> handleConstraintViolation(ConstraintViolationException e) {
        // 在控制台打印日志
        handleLogging(e);

        String traceId = TraceIdContext.currentTraceId();
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(ApiCode.REQ_VALIDATION, e.getMessage(), traceId));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Object>> handleUnknown(Exception e) {
        // 在控制台打印日志
        handleLogging(e);

        String traceId = TraceIdContext.currentTraceId();
        // 生产和开发环境均不向前端暴露堆栈
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.error(ApiCode.INTERNAL_ERROR, null, traceId));
    }

    /**
     * 统一日志处理：仅作用于服务器控制台/日志文件
     */
    private void handleLogging(Exception e) {
        if (showStacktrace) {
            // 开发环境：控制台打印详细堆栈，方便定位代码
            log.error("Exception occurred: ", e);
        } else {
            // 生产环境：只记录异常类型和消息，避免日志爆炸
            log.error("Exception occurred: [{}] {}", e.getClass().getSimpleName(), e.getMessage());
        }
    }
}