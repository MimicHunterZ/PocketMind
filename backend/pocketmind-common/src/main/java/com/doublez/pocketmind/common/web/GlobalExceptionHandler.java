package com.doublez.pocketmind.common.web;

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

    // 浠呯敤浜庢帶鍒跺彴鏃ュ織鎵撳嵃绛栫暐锛歞ev妯″紡鎵撳嵃瀹屾暣鍫嗘爤锛宲rod妯″紡鍙墦鍗版憳瑕?
    @Value("${app.exception.show-stacktrace:false}")
    private boolean showStacktrace;

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Object>> handleBusiness(BusinessException e) {
        // 鍦ㄦ帶鍒跺彴鎵撳嵃鏃ュ織
        handleLogging(e);

        String traceId = TraceIdContext.currentTraceId();
        // 鎭㈠鍘熸湁閫昏緫锛氳繑鍥炰笟鍔¤鎯咃紝涓嶅甫鍫嗘爤
        return ResponseEntity.status(e.getStatus())
                .body(ApiResponse.error(e.getCode(), e.getDetail(), traceId));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Object>> handleValidation(MethodArgumentNotValidException e) {
        // 鍦ㄦ帶鍒跺彴鎵撳嵃鏃ュ織
        handleLogging(e);

        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .filter(m -> m != null && !m.isBlank())
                .collect(Collectors.joining("; "));
        String traceId = TraceIdContext.currentTraceId();

        // message 璧扮粺涓€鏄犲皠锛屽叿浣撴牎楠屽師鍥犳斁鍒?data
        Object data = message.isBlank() ? null : message;
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(ApiCode.REQ_VALIDATION, data, traceId));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiResponse<Object>> handleConstraintViolation(ConstraintViolationException e) {
        // 鍦ㄦ帶鍒跺彴鎵撳嵃鏃ュ織
        handleLogging(e);

        String traceId = TraceIdContext.currentTraceId();
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(ApiCode.REQ_VALIDATION, e.getMessage(), traceId));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Object>> handleUnknown(Exception e) {
        // 鍦ㄦ帶鍒跺彴鎵撳嵃鏃ュ織
        handleLogging(e);

        String traceId = TraceIdContext.currentTraceId();
        // 鐢熶骇鍜屽紑鍙戠幆澧冨潎涓嶅悜鍓嶇鏆撮湶鍫嗘爤
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.error(ApiCode.INTERNAL_ERROR, null, traceId));
    }

    /**
     * Broken Pipe 瀹瑰繊锛氬鎴风锛堢Щ鍔ㄧ/娴忚鍣級涓诲姩鍏抽棴杩炴帴鏃讹紝Tomcat 鎶涘嚭姝ゅ紓甯搞€?
     * 鍥剧墖鍔犺浇涓€斿彇娑堛€佸垏鎹㈤〉闈㈢瓑鍧囦細瑙﹀彂銆?
     * 浠呮墦鍗?WARN 鏃ュ織锛屼弗绂佹墦鍗板爢鏍堬紝閬垮厤澶ч噺鍥剧墖鍔犺浇鍦烘櫙涓嬬殑鏃ュ織闆穿銆?
     */
    @ExceptionHandler(ClientAbortException.class)
    public ResponseEntity<Void> handleClientAbort(ClientAbortException e) {
        log.warn("[AssetServe] 瀹㈡埛绔富鍔ㄥ叧闂繛鎺ワ紝浼犺緭涓: {}", e.getMessage());
        // 499 = Client Closed Request锛圢ginx 鎯緥锛岃〃绀哄鎴风涓诲姩鏂紑锛?
        return ResponseEntity.status(499).build();
    }

    /**
     * 缁熶竴鏃ュ織澶勭悊锛氫粎浣滅敤浜庢湇鍔″櫒鎺у埗鍙?鏃ュ織鏂囦欢
     */
    private void handleLogging(Exception e) {
        if (showStacktrace) {
            // 寮€鍙戠幆澧冿細鎺у埗鍙版墦鍗拌缁嗗爢鏍堬紝鏂逛究瀹氫綅浠ｇ爜
            log.error("Exception occurred: ", e);
        } else {
            // 鐢熶骇鐜锛氬彧璁板綍寮傚父绫诲瀷鍜屾秷鎭紝閬垮厤鏃ュ織鐖嗙偢
            log.error("Exception occurred: [{}] {}", e.getClass().getSimpleName(), e.getMessage());
        }
    }
}
