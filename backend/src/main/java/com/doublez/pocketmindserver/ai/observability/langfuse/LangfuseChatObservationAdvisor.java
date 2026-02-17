package com.doublez.pocketmindserver.ai.observability.langfuse;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.json.JsonMapper;
import lombok.extern.slf4j.Slf4j;
import org.jetbrains.annotations.NotNull;
import org.springframework.ai.chat.client.ChatClientRequest;
import org.springframework.ai.chat.client.ChatClientResponse;
import org.springframework.ai.chat.client.advisor.api.AdvisorChain;
import org.springframework.ai.chat.client.advisor.api.BaseAdvisor;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.chat.model.Generation;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.core.Ordered;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Langfuse OTel 展示适配。
 *
 * Langfuse 会从 span 的 langfuse.observation.input/output 读取并展示。
 * Spring AI 默认写在 spring_ai.* attributes 中，因此需要在 ChatClient Advisor 层进行映射。
 */
@Slf4j
public class LangfuseChatObservationAdvisor implements BaseAdvisor {

    private final JsonMapper jsonMapper;

    public LangfuseChatObservationAdvisor(JsonMapper jsonMapper) {
        this.jsonMapper = jsonMapper;
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE;
    }

    @Override
    public @NotNull ChatClientRequest before(@NotNull ChatClientRequest chatClientRequest, @NotNull AdvisorChain advisorChain) {
        try {
            Prompt prompt = chatClientRequest.prompt();
            String promptJson = toPromptJson(prompt);
            LangfuseSpanWriter.trySetObservationInput(promptJson);
            LangfuseSpanWriter.trySetMetadata("prompt_message_count", prompt.getInstructions().size());

            Object contextMode = chatClientRequest.context().get("contextMode");
            if (contextMode != null) {
                LangfuseSpanWriter.trySetMetadata("context_mode", String.valueOf(contextMode));
            }
        } catch (Exception e) {
            // 观测增强不影响主流程。
            log.debug("写入 Langfuse chat input 失败: {}", e.getMessage());
        }
        return chatClientRequest;
    }

    @Override
    public @NotNull ChatClientResponse after(@NotNull ChatClientResponse chatClientResponse, @NotNull AdvisorChain advisorChain) {
        try {
            String completionJson = toCompletionJson(chatClientResponse.chatResponse());
            LangfuseSpanWriter.trySetObservationOutput(completionJson);
        } catch (Exception e) {
            log.debug("写入 Langfuse chat output 失败: {}", e.getMessage());
        }
        return chatClientResponse;
    }

    private String toPromptJson(Prompt prompt) throws JsonProcessingException {
        Map<String, Object> payload = new LinkedHashMap<>();
        if (prompt == null) {
            payload.put("messages", List.of());
            payload.put("options", null);
            return jsonMapper.writeValueAsString(payload);
        }

        List<Map<String, Object>> messages = new ArrayList<>();
        for (Message msg : prompt.getInstructions()) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("type", msg.getClass().getSimpleName());
            item.put("text", msg.getText());
            item.put("metadata", msg.getMetadata());
            if (msg instanceof AssistantMessage assistantMessage) {
                item.put("toolCalls", assistantMessage.getToolCalls());
            }
            messages.add(item);
        }

        payload.put("messages", messages);
        payload.put("options", prompt.getOptions());
        return jsonMapper.writeValueAsString(payload);
    }

    private String toCompletionJson(ChatResponse chatResponse) throws JsonProcessingException {
        Map<String, Object> payload = new LinkedHashMap<>();
        if (chatResponse == null) {
            payload.put("assistantText", null);
            payload.put("toolCalls", List.of());
            payload.put("metadata", null);
            return jsonMapper.writeValueAsString(payload);
        }

        Generation generation = chatResponse.getResult();
        AssistantMessage output = generation == null ? null : generation.getOutput();

        payload.put("assistantText", output == null ? null : output.getText());
        payload.put("toolCalls", output == null ? List.of() : output.getToolCalls());
        payload.put("generationMetadata", generation == null ? null : generation.getMetadata());
        payload.put("responseMetadata", chatResponse.getMetadata());
        return jsonMapper.writeValueAsString(payload);
    }
}
