package com.doublez.pocketmindserver.agui;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * AG-UI 协议事件的最小 Java 建模，字段名对齐 {@code ag_ui ^0.3.0} Dart 包（camelCase）。
 *
 * 不依赖任何聊天业务类型（session/message/tool 实体），也不引入任何 AG-UI 官方 SDK——
 * 纯粹是"事件长什么样、序列化成什么 JSON"这一层协议知识，业务层（如聊天 SSE）拿具体
 * 业务数据构造这里的事件、再交给 {@link AgUiEventEncoder} 编码，两者互不感知。
 *
 * 各事件类分组对应官方事件词汇：生命周期（Run*）、文本消息（TextMessage*）、
 * 工具调用（ToolCall*）、兜底（Custom）。Reasoning/State/Activity 等未用到的事件族
 * 本次不建模，需要时按同样模式补充即可。
 *
 * 和 Dart 端一样，把整棵 sealed 继承树放在同一个文件里：Java 的 sealed interface
 * 也要求 permits 的实现类在同一编译单元内可见，分文件反而要维护额外的可见性声明。
 */
public sealed interface AgUiEvent {

    /** AG-UI 协议里的事件类型字符串，如 {@code "TEXT_MESSAGE_CONTENT"}。 */
    String type();

    /** 该事件除 {@code type} 外的自有字段。 */
    Map<String, Object> fields();

    /** 完整的 wire-format JSON：{@code type} 字段 + 自有字段。 */
    default Map<String, Object> toJson() {
        Map<String, Object> json = new LinkedHashMap<>();
        json.put("type", type());
        json.putAll(fields());
        return json;
    }

    // ------------------------------------------------------------------
    // 生命周期事件
    // ------------------------------------------------------------------

    record RunStarted(String threadId, String runId) implements AgUiEvent {
        @Override
        public String type() {
            return "RUN_STARTED";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("threadId", threadId);
            m.put("runId", runId);
            return m;
        }
    }

    record RunFinished(String threadId, String runId, Object result) implements AgUiEvent {
        public RunFinished(String threadId, String runId) {
            this(threadId, runId, null);
        }

        @Override
        public String type() {
            return "RUN_FINISHED";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("threadId", threadId);
            m.put("runId", runId);
            if (result != null) {
                m.put("result", result);
            }
            return m;
        }
    }

    record RunError(String message, String code) implements AgUiEvent {
        public RunError(String message) {
            this(message, null);
        }

        @Override
        public String type() {
            return "RUN_ERROR";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("message", message);
            if (code != null) {
                m.put("code", code);
            }
            return m;
        }
    }

    // ------------------------------------------------------------------
    // 文本消息事件
    // ------------------------------------------------------------------

    record TextMessageStart(String messageId, String role) implements AgUiEvent {
        public TextMessageStart(String messageId) {
            this(messageId, "assistant");
        }

        @Override
        public String type() {
            return "TEXT_MESSAGE_START";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("messageId", messageId);
            m.put("role", role);
            return m;
        }
    }

    record TextMessageContent(String messageId, String delta) implements AgUiEvent {
        @Override
        public String type() {
            return "TEXT_MESSAGE_CONTENT";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("messageId", messageId);
            m.put("delta", delta);
            return m;
        }
    }

    record TextMessageEnd(String messageId) implements AgUiEvent {
        @Override
        public String type() {
            return "TEXT_MESSAGE_END";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("messageId", messageId);
            return m;
        }
    }

    // ------------------------------------------------------------------
    // 工具调用事件
    // ------------------------------------------------------------------

    record ToolCallStart(String toolCallId, String toolCallName, String parentMessageId) implements AgUiEvent {
        public ToolCallStart(String toolCallId, String toolCallName) {
            this(toolCallId, toolCallName, null);
        }

        @Override
        public String type() {
            return "TOOL_CALL_START";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("toolCallId", toolCallId);
            m.put("toolCallName", toolCallName);
            if (parentMessageId != null) {
                m.put("parentMessageId", parentMessageId);
            }
            return m;
        }
    }

    record ToolCallEnd(String toolCallId) implements AgUiEvent {
        @Override
        public String type() {
            return "TOOL_CALL_END";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("toolCallId", toolCallId);
            return m;
        }
    }

    record ToolCallResult(String messageId, String toolCallId, String content) implements AgUiEvent {
        @Override
        public String type() {
            return "TOOL_CALL_RESULT";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("messageId", messageId);
            m.put("toolCallId", toolCallId);
            m.put("content", content);
            m.put("role", "tool");
            return m;
        }
    }

    // ------------------------------------------------------------------
    // 活动事件：工具执行结果不是普通文本、而是要交给前端某种专用渲染器处理的
    // 结构化内容（如 A2UI 卡片）时用这个事件，取代 ToolCallResult——渲染器
    // 消费的是 content 里的结构化数据本身，不是"工具返回了什么文本"这个语义。
    // ------------------------------------------------------------------

    record ActivitySnapshot(String messageId, String activityType, Object content, boolean replace) implements AgUiEvent {
        public ActivitySnapshot(String messageId, String activityType, Object content) {
            this(messageId, activityType, content, true);
        }

        @Override
        public String type() {
            return "ACTIVITY_SNAPSHOT";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("messageId", messageId);
            m.put("activityType", activityType);
            m.put("content", content);
            m.put("replace", replace);
            return m;
        }
    }

    // ------------------------------------------------------------------
    // 兜底事件：协议词汇里没有对应事件的场景（如用户主动打断生成）走这里，
    // 而不是发明一个不在 AG-UI 词汇表里的自定义事件名。
    // ------------------------------------------------------------------

    record Custom(String name, Object value) implements AgUiEvent {
        @Override
        public String type() {
            return "CUSTOM";
        }

        @Override
        public Map<String, Object> fields() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("name", name);
            m.put("value", value);
            return m;
        }
    }
}
