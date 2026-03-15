package com.doublez.pocketmindserver.chat.domain.message;

/**
 * 消息类型枚举
 */
public enum ChatMessageType {
    TEXT("TEXT"),
    TOOL_CALL("TOOL_CALL"),
    TOOL_RESULT("TOOL_RESULT");

    private final String value;

    ChatMessageType(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }
}
