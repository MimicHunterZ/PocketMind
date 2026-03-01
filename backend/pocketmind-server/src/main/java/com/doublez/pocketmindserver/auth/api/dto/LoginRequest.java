package com.doublez.pocketmindserver.auth.api.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank(message = "username 不能为空")
        String username,
        @NotBlank(message = "password 不能为空")
        String password
) {
}
