package com.doublez.pocketmindserver.ai.api.dto.chat;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 更新分支别名请求体（用户手动编辑分支标签）
 */
public record UpdateAliasRequest(
        @NotBlank(message = "别名不能为空")
        @Size(max = 10, message = "别名最多 10 个字符")
        String alias
) {
}
