package com.doublez.pocketmindserver.demo;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.opentelemetry.api.trace.Span;
import lombok.extern.slf4j.Slf4j;
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
 * demo 专用：Langfuse OTel 集成需要从 span 的 langfuse.observation.input/output 读取并展示。
 * Spring AI 默认把 prompt/completion 放在 spring_ai.* attributes 中，Langfuse UI 会显示为 undefined。
 *
 * 这里通过 ChatClient Advisor 把“发送给模型的 prompt（全量）”与“模型返回的 completion（全量）”
 * 映射到 langfuse.observation.input/output，便于做上下文评估。
 */
@Slf4j
public class LangfuseChatObservationAdvisor implements BaseAdvisor {

    private final ObjectMapper objectMapper;

    public LangfuseChatObservationAdvisor(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public int getOrder() {
        // 尽早执行，确保在同一个 chat span 上写入 input/output。
        return Ordered.HIGHEST_PRECEDENCE;
    }

    @Override
    public ChatClientRequest before(ChatClientRequest chatClientRequest, AdvisorChain advisorChain) {
        Span span = Span.current();
        if (span != null && span.getSpanContext().isValid()) {
            try {
                Prompt prompt = chatClientRequest.prompt();
                String promptJson = toPromptJson(prompt);
                span.setAttribute("langfuse.observation.input", promptJson);
                span.setAttribute("langfuse.observation.metadata.prompt_message_count",
                        prompt == null ? 0 : prompt.getInstructions().size());

                Object contextMode = chatClientRequest.context().get("contextMode");
                if (contextMode != null) {
                    span.setAttribute("langfuse.observation.metadata.context_mode", String.valueOf(contextMode));
                }
            } catch (Exception e) {
                // 这里不影响主流程，只做观测增强。
                log.debug("写入 Langfuse chat input 失败: {}", e.getMessage());
            }
        }
        return chatClientRequest;
    }

    @Override
    public ChatClientResponse after(ChatClientResponse chatClientResponse, AdvisorChain advisorChain) {
        Span span = Span.current();
        if (span != null && span.getSpanContext().isValid()) {
            try {
                String completionJson = toCompletionJson(chatClientResponse.chatResponse());
                span.setAttribute("langfuse.observation.output", completionJson);
            } catch (Exception e) {
                log.debug("写入 Langfuse chat output 失败: {}", e.getMessage());
            }
        }
        return chatClientResponse;
    }

    private String toPromptJson(Prompt prompt) throws JsonProcessingException {
        Map<String, Object> payload = new LinkedHashMap<>();
        if (prompt == null) {
            payload.put("messages", List.of());
            payload.put("options", null);
            return objectMapper.writeValueAsString(payload);
        }

        List<Map<String, Object>> messages = new ArrayList<>();
        for (Message msg : prompt.getInstructions()) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("type", msg == null ? "null" : msg.getClass().getSimpleName());
            item.put("text", msg == null ? null : msg.getText());
            item.put("metadata", msg == null ? null : msg.getMetadata());
            if (msg instanceof AssistantMessage assistantMessage) {
                item.put("toolCalls", assistantMessage.getToolCalls());
            }
            messages.add(item);
        }

        payload.put("messages", messages);
        payload.put("options", prompt.getOptions());
        return objectMapper.writeValueAsString(payload);
    }

    private String toCompletionJson(ChatResponse chatResponse) throws JsonProcessingException {
        Map<String, Object> payload = new LinkedHashMap<>();
        if (chatResponse == null) {
            payload.put("assistantText", null);
            payload.put("toolCalls", List.of());
            payload.put("metadata", null);
            return objectMapper.writeValueAsString(payload);
        }

        Generation generation = chatResponse.getResult();
        AssistantMessage output = generation == null ? null : generation.getOutput();

        payload.put("assistantText", output == null ? null : output.getText());
        payload.put("toolCalls", output == null ? List.of() : output.getToolCalls());
        payload.put("generationMetadata", generation == null ? null : generation.getMetadata());
        payload.put("responseMetadata", chatResponse.getMetadata());
        return objectMapper.writeValueAsString(payload);
    }
}
