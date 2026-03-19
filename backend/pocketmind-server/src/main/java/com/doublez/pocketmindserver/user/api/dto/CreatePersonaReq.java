package com.doublez.pocketmindserver.user.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class CreatePersonaReq {
    @NotBlank(message = "人设名称不能为空")
    private String name;

    @NotBlank(message = "系统提示词不能为空")
    private String systemPrompt;
}