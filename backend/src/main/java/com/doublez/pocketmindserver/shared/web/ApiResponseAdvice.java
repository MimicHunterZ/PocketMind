package com.doublez.pocketmindserver.shared.web;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.MethodParameter;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.ResourceRegion;
import org.springframework.http.MediaType;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseBodyAdvice;

/**
 * 统一包装成功响应为 ApiResponse
 */
@RestControllerAdvice
public class ApiResponseAdvice implements ResponseBodyAdvice<Object> {

    private final ObjectMapper objectMapper;

    public ApiResponseAdvice(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean supports(MethodParameter returnType, Class<? extends HttpMessageConverter<?>> converterType) {
        return true;
    }

    @Override
    public Object beforeBodyWrite(Object body,
                                  MethodParameter returnType,
                                  MediaType selectedContentType,
                                  Class<? extends HttpMessageConverter<?>> selectedConverterType,
                                  ServerHttpRequest request,
                                  ServerHttpResponse response) {
        if (body instanceof ApiResponse<?>) {
            return body;
        }
        // 二进制资源（图片/文件流），不做 JSON 包装直接透传
        if (body instanceof Resource || body instanceof ResourceRegion) {
            return body;
        }

        String traceId = TraceIdContext.currentTraceId();
        ApiResponse<Object> wrapped = ApiResponse.ok(body, traceId);

        // String 返回值需要特殊处理，否则会走 StringHttpMessageConverter
        if (String.class.equals(returnType.getParameterType())) {
            try {
                return objectMapper.writeValueAsString(wrapped);
            } catch (JsonProcessingException e) {
                return "{\"code\":" + ApiCode.INTERNAL_ERROR.code() + ",\"message\":\"" + ApiCode.INTERNAL_ERROR.defaultMessage() + "\",\"data\":null,\"traceId\":\"" + traceId + "\"}";
            }
        }

        return wrapped;
    }
}
