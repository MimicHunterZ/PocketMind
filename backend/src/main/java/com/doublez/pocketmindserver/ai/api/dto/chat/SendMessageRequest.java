package com.doublez.pocketmindserver.ai.api.dto.chat;

import jakarta.validation.constraints.NotBlank;

import java.util.List;
import java.util.UUID;

/**
 * 发送消息请求体
 */
public record SendMessageRequest(
        // 用户消息内容
        @NotBlank(message = "消息内容不能为空")
        String content,
        // 附件 UUID 列表（可选）
        List<UUID> attachmentUuids,
        // 分支模式：指定父消息 UUID，从该节点创建新分支（可选，null 表示线性追加）
        UUID parentUuid
) {
    public List<UUID> safeAttachmentUuids() {
        return attachmentUuids != null ? attachmentUuids : List.of();
    }
}
