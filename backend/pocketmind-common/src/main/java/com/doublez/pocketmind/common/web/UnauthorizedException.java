package com.doublez.pocketmind.common.web;

import org.springframework.http.HttpStatus;

public class UnauthorizedException extends BusinessException {

    public UnauthorizedException(String message) {
        super(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED, message);
    }
}

