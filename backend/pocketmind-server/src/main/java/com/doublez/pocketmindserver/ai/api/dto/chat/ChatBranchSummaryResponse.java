package com.doublez.pocketmindserver.ai.api.dto.chat;

import java.util.UUID;

/**
 * 分支摘要响应体
 *
 * <p>leafUuid - 该分支链的叶节点 UUID（最新消息）
 * <p>branchAlias - AI 生成的 4-8 字命名（可为 null，表示还未生成）
 * <p>lastUserContent - 分支末端最后一轮 USER 消息的内容（前 200 字，供前端 2 行展示）
 * <p>lastAssistantContent - 分支末端最后一轮 ASSISTANT 消息的内容（前 200 字）
 * <p>updatedAt - 叶节点的最后更新时间（毫秒）
 */
public record ChatBranchSummaryResponse(
        UUID leafUuid,
        String branchAlias,
        String lastUserContent,
        String lastAssistantContent,
        long updatedAt
) {
}
