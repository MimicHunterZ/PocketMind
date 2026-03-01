package com.doublez.pocketmind.common.web;

/**
 * 缁熶竴鍝嶅簲缁撴瀯
 *
 * @param code    涓氬姟鐮?
 * @param message 鎻愮ず淇℃伅
 * @param data    鏁版嵁
 * @param traceId 閾捐矾杩借釜ID
 */
public record ApiResponse<T>(
        int code,
        String message,
        T data,
        String traceId
) {

    public static <T> ApiResponse<T> ok(T data, String traceId) {
        return new ApiResponse<>(ApiCode.OK.code(), ApiCode.OK.defaultMessage(), data, traceId);
    }

    public static <T> ApiResponse<T> error(ApiCode code, T data, String traceId) {
        return new ApiResponse<>(code.code(), code.defaultMessage(), data, traceId);
    }

    public static ApiResponse<Void> error(ApiCode code, String traceId) {
        return error(code, null, traceId);
    }
}

