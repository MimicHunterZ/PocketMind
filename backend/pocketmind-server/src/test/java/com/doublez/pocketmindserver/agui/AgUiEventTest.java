package com.doublez.pocketmindserver.agui;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.http.codec.ServerSentEvent;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class AgUiEventTest {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final AgUiEventEncoder encoder = new AgUiEventEncoder(objectMapper);

    @Test
    void runStarted_fieldsMatchAgUiWireFormat() {
        var event = new AgUiEvent.RunStarted("session-1", "req-1");

        assertThat(event.type()).isEqualTo("RUN_STARTED");
        assertThat(event.toJson())
                .containsEntry("type", "RUN_STARTED")
                .containsEntry("threadId", "session-1")
                .containsEntry("runId", "req-1");
    }

    @Test
    void runFinished_omitsResultWhenNull() {
        var event = new AgUiEvent.RunFinished("session-1", "req-1");

        assertThat(event.toJson()).doesNotContainKey("result");
    }

    @Test
    void runFinished_includesResultWhenPresent() {
        var event = new AgUiEvent.RunFinished("session-1", "req-1", "ok");

        assertThat(event.toJson()).containsEntry("result", "ok");
    }

    @Test
    void textMessageStart_defaultsRoleToAssistant() {
        var event = new AgUiEvent.TextMessageStart("msg-1");

        assertThat(event.toJson())
                .containsEntry("messageId", "msg-1")
                .containsEntry("role", "assistant");
    }

    @Test
    void toolCallStart_omitsParentMessageIdWhenNull() {
        var event = new AgUiEvent.ToolCallStart("call-1", "searchMemories");

        assertThat(event.toJson())
                .containsEntry("toolCallId", "call-1")
                .containsEntry("toolCallName", "searchMemories")
                .doesNotContainKey("parentMessageId");
    }

    @Test
    void toolCallResult_alwaysTagsToolRole() {
        var event = new AgUiEvent.ToolCallResult("msg-2", "call-1", "{\"ok\":true}");

        assertThat(event.toJson())
                .containsEntry("messageId", "msg-2")
                .containsEntry("toolCallId", "call-1")
                .containsEntry("content", "{\"ok\":true}")
                .containsEntry("role", "tool");
    }

    @Test
    void custom_keepsValuePresentEvenWhenNull() {
        var event = new AgUiEvent.Custom("chat.paused", null);

        assertThat(event.toJson())
                .containsEntry("name", "chat.paused")
                .containsKey("value");
        assertThat(event.toJson().get("value")).isNull();
    }

    @Test
    void activitySnapshot_defaultsReplaceToTrue() {
        var event = new AgUiEvent.ActivitySnapshot("msg-3", "a2ui-surface", Map.of("version", "v0.9"));

        assertThat(event.type()).isEqualTo("ACTIVITY_SNAPSHOT");
        assertThat(event.toJson())
                .containsEntry("messageId", "msg-3")
                .containsEntry("activityType", "a2ui-surface")
                .containsEntry("content", Map.of("version", "v0.9"))
                .containsEntry("replace", true);
    }

    @Test
    void activitySnapshot_keepsContentKeyPresentEvenWhenNull() {
        var event = new AgUiEvent.ActivitySnapshot("msg-4", "a2ui-surface", null, false);

        assertThat(event.toJson())
                .containsKey("content")
                .containsEntry("replace", false);
        assertThat(event.toJson().get("content")).isNull();
    }

    @Test
    void encoder_setsSseEventNameToAgUiType() {
        ServerSentEvent<String> sse = encoder.encode(new AgUiEvent.ToolCallEnd("call-1"));

        assertThat(sse.event()).isEqualTo("TOOL_CALL_END");
        assertThat(sse.data()).contains("\"type\":\"TOOL_CALL_END\"").contains("\"toolCallId\":\"call-1\"");
    }
}
