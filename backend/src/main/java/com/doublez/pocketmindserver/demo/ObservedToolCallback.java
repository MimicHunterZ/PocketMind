package com.doublez.pocketmindserver.demo;

import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.ai.chat.model.ToolContext;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.ai.tool.definition.ToolDefinition;
import org.springframework.ai.tool.metadata.ToolMetadata;

import java.util.concurrent.TimeUnit;

/**
 * 工具调用观测包装器：记录每次工具调用的输入、输出摘要、耗时和异常
 */
@Slf4j
public class ObservedToolCallback implements ToolCallback {

    private final ToolCallback delegate;
    private final ToolResultContextEngineer contextEngineer;
    private final boolean logFullPayload;
    private final int maxPayloadLength;
    private final boolean logToolContext;

    public ObservedToolCallback(ToolCallback delegate,
                                ToolResultContextEngineer contextEngineer,
                                boolean logFullPayload,
                                int maxPayloadLength,
                                boolean logToolContext) {
        this.delegate = delegate;
        this.contextEngineer = contextEngineer;
        this.logFullPayload = logFullPayload;
        this.maxPayloadLength = maxPayloadLength;
        this.logToolContext = logToolContext;
    }

    @Override
    public ToolDefinition getToolDefinition() {
        return delegate.getToolDefinition();
    }

    @Override
    public ToolMetadata getToolMetadata() {
        return delegate.getToolMetadata();
    }

    @Override
    public String call(String toolInput) {
        return observe(toolInput, null);
    }

    @Override
    public String call(String toolInput, ToolContext toolContext) {
        return observe(toolInput, toolContext);
    }

    private String observe(String toolInput, ToolContext toolContext) {
        String toolName = getToolDefinition() != null ? getToolDefinition().name() : "unknown";
        String traceId = MDC.get("traceId");
        long startNanos = System.nanoTime();
        String formattedInput = formatPayload(toolInput);
        String contextPayload = toolContext == null ? "null" : formatPayload(String.valueOf(toolContext.getContext()));

        if (logToolContext) {
            log.debug("工具调用开始 - traceId: {}, tool: {}, input: {}, context: {}",
                    traceId,
                    toolName,
                    formattedInput,
                    contextPayload);
        } else {
            log.debug("工具调用开始 - traceId: {}, tool: {}, input: {}", traceId, toolName, formattedInput);
        }

        try {
            String rawResult = toolContext == null ? delegate.call(toolInput) : delegate.call(toolInput, toolContext);
            String result = contextEngineer.process(toolName, rawResult);
            long latencyMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);
            log.debug("工具调用完成 - traceId: {}, tool: {}, latencyMs: {}, result: {}",
                traceId, toolName, latencyMs, formatPayload(result));
            return result;
        } catch (Exception exception) {
            long latencyMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);
            log.error("工具调用失败 - traceId: {}, tool: {}, latencyMs: {}, input: {}, error: {}",
                    traceId, toolName, latencyMs, formattedInput, exception.getMessage(), exception);
            throw exception;
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
}
