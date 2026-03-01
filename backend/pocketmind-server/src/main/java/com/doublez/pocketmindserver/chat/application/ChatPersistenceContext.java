package com.doublez.pocketmindserver.chat.application;

import java.util.UUID;

/**
 * AI 对话持久化上下文（线程绑定）。
 * 用于 ToolCallAdvisor 在递归工具调用过程中，将 tool_call/tool_result 按顺序落库，并维护 parent_uuid 链路。
 */
public record ChatPersistenceContext(
        long userId,
        UUID sessionUuid,
        UUID parentUuid
) {
}
