package com.doublez.pocketmindserver.user.api.dto;

import lombok.Data;

@Data
public class UserPersonaDto {
    private Long id;
    private String name;
    private String systemPrompt;
    private Long updatedAt;
}