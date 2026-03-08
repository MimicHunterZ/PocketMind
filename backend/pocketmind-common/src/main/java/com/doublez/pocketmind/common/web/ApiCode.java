package com.doublez.pocketmind.common.web;

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
    NOTE_SAVE_FAILED(502001, "笔记保存失败"),
    NOTE_UPDATE_FAILED(502002, "笔记更新失败"),
    CHAT_SESSION_SAVE_FAILED(502003, "会话保存失败"),
    CHAT_MESSAGE_SAVE_FAILED(502004, "消息保存失败"),
    CHAT_MESSAGE_UPDATE_FAILED(502007, "消息更新失败"),
    ATTACHMENT_SAVE_FAILED(502005, "附件保存失败"),
    VISION_SAVE_FAILED(502006, "Vision 记录保存失败"),

    ASSET_UPLOAD_FAILED(503001, "图片上传失败"),
    ASSET_INVALID_FORMAT(503002, "不支持的图片格式"),
    ASSET_NOT_FOUND(503003, "图片资产不存在或无权访问"),

    SYNC_PUSH_FAILED(504001, "同步推送处理失败"),
    SYNC_PULL_FAILED(504002, "同步拉取失败"),
    SYNC_INVALID_ENTITY_TYPE(504003, "不支持的实体类型"),

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

