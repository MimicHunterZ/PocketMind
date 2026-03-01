package com.doublez.pocketmindserver.auth.api.dto;

public record AuthTokenResponse(
        String userId,
        String token,
        long expiresInSeconds
) {
}
