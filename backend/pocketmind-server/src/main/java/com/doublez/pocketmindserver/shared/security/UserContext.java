package com.doublez.pocketmindserver.shared.security;

import com.doublez.pocketmind.common.web.UnauthorizedException;

public final class UserContext {

    private static final ThreadLocal<String> USER_ID = new ThreadLocal<>();

    private UserContext() {
    }

    public static void setUserId(String userId) {
        USER_ID.set(userId);
    }

    public static String getUserId() {
        return USER_ID.get();
    }

    public static String getRequiredUserId() {
        String userId = USER_ID.get();
        if (userId == null || userId.isBlank()) {
            throw new UnauthorizedException("未登录");
        }
        return userId;
    }

    public static void clear() {
        USER_ID.remove();
    }
}

