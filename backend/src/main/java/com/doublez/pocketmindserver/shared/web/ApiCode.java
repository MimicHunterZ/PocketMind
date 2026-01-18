package com.doublez.pocketmindserver.shared.web;

/**
 * 统一业务码（数字）与默认提示文案映射
 */
public enum ApiCode {

    OK(200, "success"),

    REQ_VALIDATION(400001, "参数校验失败"),

    AUTH_UNAUTHORIZED(401001, "未授权"),
    AUTH_BAD_CREDENTIALS(401002, "用户名或密码错误"),
    AUTH_USERNAME_EXISTS(401003, "用户名已存在"),

    AUTH_REGISTER_FAILED(400104, "注册失败"),
    RESOURCE_NOT_FOUND(501001, "资源不存在或处理失败"),
    AI_RESPONSE_ERROR(501002, "AI服务响应异常"),
    INTERNAL_ERROR(500000, "服务器内部错误");

    private final int code;
    private final String defaultMessage;

    ApiCode(int code, String defaultMessage) {
        this.code = code;
        this.defaultMessage = defaultMessage;
    }

    public int code() {
        return code;
    }

    public String defaultMessage() {
        return defaultMessage;
    }
}
