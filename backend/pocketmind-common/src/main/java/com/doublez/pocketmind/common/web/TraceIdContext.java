package com.doublez.pocketmind.common.web;

import org.slf4j.MDC;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import jakarta.servlet.http.HttpServletRequest;

/**
 * 缁熶竴鑾峰彇 traceId锛堜紭鍏?request attribute锛屽叾娆?MDC锛?
 */
public final class TraceIdContext {

    private TraceIdContext() {
    }

    public static String currentTraceId() {
        HttpServletRequest request = currentRequest();
        if (request != null) {
            Object value = request.getAttribute(TraceIdFilter.TRACE_ID_KEY);
            if (value != null) {
                return String.valueOf(value);
            }
        }
        String mdc = MDC.get(TraceIdFilter.TRACE_ID_KEY);
        return mdc == null ? "" : mdc;
    }

    private static HttpServletRequest currentRequest() {
        RequestAttributes attributes = RequestContextHolder.getRequestAttributes();
        if (attributes instanceof ServletRequestAttributes servletRequestAttributes) {
            return servletRequestAttributes.getRequest();
        }
        return null;
    }
}

