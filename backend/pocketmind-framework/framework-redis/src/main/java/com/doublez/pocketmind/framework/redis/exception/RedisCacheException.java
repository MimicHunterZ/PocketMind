package com.doublez.pocketmind.framework.redis.exception;

public class RedisCacheException extends RuntimeException {

    public RedisCacheException(String message, Throwable cause) {
        super(message, cause);
    }
}