package com.doublez.pocketmindserver.chat.domain.message;

/** 消息角色 */
public enum ChatRole {
    USER,
    ASSISTANT,
    SYSTEM,
    /** AI 发起的工具调用请求 */
    TOOL_CALL,
    /** 工具执行结果 */
    TOOL_RESULT
}
