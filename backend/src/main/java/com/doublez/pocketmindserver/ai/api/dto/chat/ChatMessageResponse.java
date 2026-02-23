package com.doublez.pocketmindserver.ai.api.dto.chat;

import java.util.List;
import java.util.UUID;

/**
 * 聊天消息响应体。
 *
 * <p>messageType 决定如何渲染：
 * <ul>
 *   <li>TEXT       - 普通文本消息，读 content 字段</li>
 *   <li>TOOL_CALL  - AI 工具调用，读 toolData（toolName / arguments）</li>
 *   <li>TOOL_RESULT- 工具调用结果，读 toolData（toolName / result）</li>
 * </ul>
 * </p>
 */
public record ChatMessageResponse(
        UUID uuid,
        UUID sessionUuid,
        UUID parentUuid,
        // 消息角色：USER / ASSISTANT / TOOL_CALL / TOOL_RESULT
        String role,
        // 消息类型：TEXT / TOOL_CALL / TOOL_RESULT，控制客户端渲染方式
        String messageType,
        /*
         * 消息内容。
         * TEXT 类型：人类可读文本；
         * TOOL_CALL / TOOL_RESULT 类型：原始 JSON 字符串（toolData 已解析为结构化数据）。
         */
        String content,
        List<UUID> attachmentUuids,
        // 创建时间（毫秒时间戳，proxied from updatedAt）
        long createdAt,
        /*
         * 工具调用元数据（仅 TOOL_CALL / TOOL_RESULT 时非 null）。
         * 供客户端渲染工具调用 UI 组件使用。
         */
        ToolCallData toolData
) {

    /**
     * 工具调用结构化数据，从 content JSON 解析而来。
     *
     * <p>TOOL_CALL 时：toolCallId / toolName / arguments 有值，result 为 null。
     * <p>TOOL_RESULT 时：toolCallId / toolName / result 有值，arguments 为 null。
     */
    public record ToolCallData(
            // 工具调用唯一 ID（关联 TOOL_CALL 和 TOOL_RESULT）
            String toolCallId,
            // 工具名称（供 UI 显示，如 "search"、"fetchNote"）
            String toolName,
            // 原始参数 JSON 字符串（仅 TOOL_CALL 时有值）
            String arguments,
            // 工具执行结果（仅 TOOL_RESULT 时有值，超长时可截断）
            String result
    ) {
    }
}
