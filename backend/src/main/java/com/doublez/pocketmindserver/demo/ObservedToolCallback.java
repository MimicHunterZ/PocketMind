package com.doublez.pocketmindserver.demo;

import io.opentelemetry.api.trace.Span;
import lombok.extern.slf4j.Slf4j;
import org.jetbrains.annotations.NotNull;
import org.slf4j.MDC;
import org.springframework.ai.chat.model.ToolContext;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.ai.tool.definition.ToolDefinition;
import org.springframework.ai.tool.metadata.ToolMetadata;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.TimeUnit;

/**
 * 工具调用观测包装器：记录每次工具调用的输入、输出摘要、耗时和异常
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
        return observe(toolInput, null);
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

        // Langfuse 的 OTel 集成会从 span 的 langfuse.observation.input/output 中读取并展示。
        // Spring AI 的工具调用 span 默认不会映射到 Langfuse 的 input/output 展示区域，所以这里显式补齐。
        Span span = Span.current();
        // Langfuse 里需要做“上下文评估”，所以写入全量原文；控制台日志仍按 maxPayloadLength 做截断。
        writeLangfuseObservationInput(span, toolName, toolInput, contextPayload, state);

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
            String rawResult = toolContext == null ? delegate.call(toolInput) : delegate.call(toolInput, toolContext);
            // 按你的要求：不对工具输出做任何“精简/压缩/改写”。
            updateState(state, toolInput, rawResult);
            long latencyMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);

            // Langfuse 里需要做“上下文评估”，所以 output 写入“回填给模型”的全量结果；并在 metadata 里保留 rawResult 全量。
                writeLangfuseObservationOutput(span, rawResult, latencyMs, state);

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
            writeLangfuseObservationError(span, exception, latencyMs);
            log.error("tool.error traceId={} tool={} latencyMs={} input={} error={}",
                    traceId, toolName, latencyMs, formattedInput, exception.getMessage(), exception);
            throw exception;
        }
    }

    private void writeLangfuseObservationInput(Span span,
                                              String toolName,
                                              String toolInput,
                                              String contextPayload,
                                              ConversationState state) {
        if (span == null || !span.getSpanContext().isValid()) {
            return;
        }
        // 为了不破坏现有 span 名称（Spring 已经命名为 tool call X），这里不强行改 name/type。
        // 只补齐 Langfuse 用来展示的 input 区域。
        span.setAttribute("langfuse.observation.input", toolInput == null ? "" : toolInput);
        span.setAttribute("langfuse.observation.metadata.tool", toolName);
        span.setAttribute("langfuse.observation.metadata.tool_context_summary", contextPayload);
        span.setAttribute("langfuse.observation.metadata.round", state.toolRounds + 1L);
    }

    private void writeLangfuseObservationOutput(Span span,
                                               String rawResult,
                                               long latencyMs,
                                               ConversationState state) {
        if (span == null || !span.getSpanContext().isValid()) {
            return;
        }
        // output 写入“回填给模型”的结果：此处保持与 rawResult 一致（不做任何精简/压缩）。
        span.setAttribute("langfuse.observation.output", rawResult == null ? "" : rawResult);
        span.setAttribute("langfuse.observation.metadata.latency_ms", latencyMs);
        span.setAttribute("langfuse.observation.metadata.est_tokens_after", state.estimatedUsedTokens);

        // rawResult 可能非常大：为了做“上下文评估”，这里写入全量原文（不截断）。
        span.setAttribute("langfuse.observation.metadata.raw_result", rawResult == null ? "" : rawResult);
    }

    private void writeLangfuseObservationError(Span span, Exception exception, long latencyMs) {
        if (span == null || !span.getSpanContext().isValid()) {
            return;
        }
        span.setAttribute("langfuse.observation.metadata.latency_ms", latencyMs);
        span.setAttribute("langfuse.observation.output", exception.getMessage() == null ? "error" : exception.getMessage());
    }

    /**
     * 仅输出上下文摘要，避免全量日志导致可读性崩坏与噪声。
     */
    private String summarizeToolContext(ToolContext toolContext) {
        if (toolContext == null || toolContext.getContext() == null) {
            return "null";
        }
        Map<String, Object> context = toolContext.getContext();
        return "keys=" + context.keySet().stream().filter(Objects::nonNull).toList();
    }

    /**
     * 会话状态更新：
     * 1. 记录估算 token（字符/4）用于判断上下文占用率。
     */
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
