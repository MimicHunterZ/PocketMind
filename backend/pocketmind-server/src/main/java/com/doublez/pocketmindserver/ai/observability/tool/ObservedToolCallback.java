package com.doublez.pocketmindserver.ai.observability.tool;

import com.doublez.pocketmindserver.ai.observability.langfuse.LangfuseSpanWriter;
import lombok.extern.slf4j.Slf4j;
import org.jetbrains.annotations.NotNull;
import org.slf4j.MDC;
import org.springframework.ai.chat.model.ToolContext;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.ai.tool.definition.ToolDefinition;
import org.springframework.ai.tool.metadata.ToolMetadata;

import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.TimeUnit;

/**
 * 工具调用观测包装器。
 * 说明：该包装器不改变工具输出内容，只做日志与 span 属性增强。
 */
@Slf4j
public class ObservedToolCallback implements ToolCallback {

    private final ToolCallback delegate;
    private final String modelName;
    private final boolean logFullPayload;
    private final int maxPayloadLength;
    private final boolean logToolContext;
    private final ConcurrentMap<String, ConversationState> conversationStates = new ConcurrentHashMap<>();
    private static final int MAX_TRACKED_CONVERSATIONS = 200;

    public ObservedToolCallback(ToolCallback delegate,
                               String modelName,
                               boolean logFullPayload,
                               int maxPayloadLength,
                               boolean logToolContext) {
        this.delegate = delegate;
        this.modelName = modelName;
        this.logFullPayload = logFullPayload;
        this.maxPayloadLength = maxPayloadLength;
        this.logToolContext = logToolContext;
    }

    @Override
    public @NotNull ToolDefinition getToolDefinition() {
        return delegate.getToolDefinition();
    }

    @Override
    public @NotNull ToolMetadata getToolMetadata() {
        return delegate.getToolMetadata();
    }

    @Override
    public @NotNull String call(@NotNull String toolInput) {
        return observe(toolInput, new ToolContext(Map.of()));
    }

    @Override
    public @NotNull String call(@NotNull String toolInput, ToolContext toolContext) {
        return observe(toolInput, toolContext);
    }

    private String observe(String toolInput, ToolContext toolContext) {
        String toolName = getToolDefinition() != null ? getToolDefinition().name() : "unknown";
        String traceId = MDC.get("traceId");
        String conversationKey = buildConversationKey(traceId);
        ConversationState state = conversationStates.computeIfAbsent(conversationKey, key -> new ConversationState());
        long startNanos = System.nanoTime();

        String formattedInput = formatPayload(toolInput);
        String contextPayload = summarizeToolContext(toolContext);

        // Langfuse 展示需要 observation.input/output。
        LangfuseSpanWriter.trySetObservationInput(toolInput);
        LangfuseSpanWriter.trySetMetadata("tool", toolName);
        LangfuseSpanWriter.trySetMetadata("tool_context_summary", contextPayload);
        LangfuseSpanWriter.trySetMetadata("round", state.toolRounds + 1L);
        LangfuseSpanWriter.trySetMetadata("model", modelName == null ? "" : modelName);

        if (logToolContext) {
            log.debug("tool.start traceId={} tool={} round={} input={} contextSummary={}",
                    traceId,
                    toolName,
                    state.toolRounds + 1,
                    formattedInput,
                    contextPayload);
        } else {
            log.debug("tool.start traceId={} tool={} round={} input={}", traceId, toolName, state.toolRounds + 1, formattedInput);
        }

        try {
            String rawResult = delegate.call(toolInput, toolContext == null ? new ToolContext(Map.of()) : toolContext);
            updateState(state, toolInput, rawResult);
            long latencyMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);

            LangfuseSpanWriter.trySetObservationOutput(rawResult);
            LangfuseSpanWriter.trySetMetadata("latency_ms", latencyMs);
            LangfuseSpanWriter.trySetMetadata("est_tokens_after", state.estimatedUsedTokens);

            log.debug("tool.end traceId={} tool={} latencyMs={} rounds={} estTokens={} result={}",
                    traceId,
                    toolName,
                    latencyMs,
                    state.toolRounds,
                    state.estimatedUsedTokens,
                    formatPayload(rawResult));
            evictWhenTooManyConversations();
            return rawResult;
        } catch (Exception exception) {
            long latencyMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);
            LangfuseSpanWriter.trySetMetadata("latency_ms", latencyMs);
            LangfuseSpanWriter.trySetObservationOutput(exception.getMessage() == null ? "error" : exception.getMessage());

            log.error("tool.error traceId={} tool={} latencyMs={} input={} error={}",
                    traceId, toolName, latencyMs, formattedInput, exception.getMessage(), exception);
            throw exception;
        }
    }

    private String summarizeToolContext(ToolContext toolContext) {
        if (toolContext == null || toolContext.getContext() == null) {
            return "null";
        }
        Map<String, Object> context = toolContext.getContext();
        return "keys=" + context.keySet().stream().filter(Objects::nonNull).toList();
    }

    private void updateState(ConversationState state,
                             String toolInput,
                             String rawResult) {
        state.toolRounds++;
        state.estimatedUsedTokens += estimateTokens(toolInput) + estimateTokens(rawResult);
    }

    private int estimateTokens(String text) {
        if (text == null || text.isBlank()) {
            return 0;
        }
        return Math.max(1, text.length() / 4);
    }

    private String buildConversationKey(String traceId) {
        if (traceId != null && !traceId.isBlank()) {
            return traceId;
        }
        return "thread-" + Thread.currentThread().getId();
    }

    private void evictWhenTooManyConversations() {
        if (conversationStates.size() <= MAX_TRACKED_CONVERSATIONS) {
            return;
        }
        String firstKey = conversationStates.keySet().stream().findFirst().orElse(null);
        if (firstKey != null) {
            conversationStates.remove(firstKey);
        }
    }

    private String formatPayload(String value) {
        if (value == null) {
            return "null";
        }
        if (logFullPayload) {
            return value;
        }
        return abbreviate(value);
    }

    private String abbreviate(String value) {
        if (value == null) {
            return "null";
        }
        if (value.length() <= maxPayloadLength) {
            return value;
        }
        return value.substring(0, maxPayloadLength) + "...(truncated," + value.length() + " chars)";
    }

    private static final class ConversationState {
        private int estimatedUsedTokens;
        private int toolRounds;
    }
}
