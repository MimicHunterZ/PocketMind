package com.doublez.pocketmind.common.web;

import org.springframework.http.HttpStatus;

public class BusinessException extends RuntimeException {

    private final ApiCode code;
    private final HttpStatus status;
    private final Object detail;

    public BusinessException(ApiCode code, HttpStatus status) {
        this(code, status, null);
    }

    public BusinessException(ApiCode code, HttpStatus status, Object detail) {
        super(code == null ? null : code.defaultMessage());
        this.code = code;
        this.status = status;
        this.detail = detail;
    }

    public ApiCode getCode() {
        return code;
    }

    public Object getDetail() {
        return detail;
    }

    public HttpStatus getStatus() {
        return status;
    }
}

