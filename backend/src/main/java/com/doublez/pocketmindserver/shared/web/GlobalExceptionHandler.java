package com.doublez.pocketmindserver.shared.web;

import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.apache.catalina.connector.ClientAbortException;
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
     * Broken Pipe 容忍：客户端（移动端/浏览器）主动关闭连接时，Tomcat 抛出此异常。
     * 图片加载中途取消、切换页面等均会触发。
     * 仅打印 WARN 日志，严禁打印堆栈，避免大量图片加载场景下的日志雪崩。
     */
    @ExceptionHandler(ClientAbortException.class)
    public ResponseEntity<Void> handleClientAbort(ClientAbortException e) {
        log.warn("[AssetServe] 客户端主动关闭连接，传输中止: {}", e.getMessage());
        // 499 = Client Closed Request（Nginx 惯例，表示客户端主动断开）
        return ResponseEntity.status(499).build();
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