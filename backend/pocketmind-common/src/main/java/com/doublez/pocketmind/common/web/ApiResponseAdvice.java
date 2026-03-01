package com.doublez.pocketmind.common.web;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Qualifier;
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
 * 缁熶竴鍖呰鎴愬姛鍝嶅簲涓?ApiResponse
 */
@RestControllerAdvice
public class ApiResponseAdvice implements ResponseBodyAdvice<Object> {

    private final ObjectMapper objectMapper;

    public ApiResponseAdvice(@Qualifier("objectMapper") ObjectMapper objectMapper) {
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
        // 浜岃繘鍒惰祫婧愶紙鍥剧墖/鏂囦欢娴侊級锛屼笉鍋?JSON 鍖呰鐩存帴閫忎紶
        if (body instanceof Resource || body instanceof ResourceRegion) {
            return body;
        }

        String traceId = TraceIdContext.currentTraceId();
        ApiResponse<Object> wrapped = ApiResponse.ok(body, traceId);

        // String 杩斿洖鍊奸渶瑕佺壒娈婂鐞嗭紝鍚﹀垯浼氳蛋 StringHttpMessageConverter
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

