package com.doublez.pocketmindserver.ai.observability.langfuse;

import io.opentelemetry.api.trace.Span;

/**
 * Langfuse span attribute 写入器。
 */
public final class LangfuseSpanWriter {

    private LangfuseSpanWriter() {
    }

    public static void trySetObservationInput(String input) {
        Span span = Span.current();
        if (span == null || !span.getSpanContext().isValid()) {
            return;
        }
        span.setAttribute(LangfuseSpanKeys.OBSERVATION_INPUT, input == null ? "" : input);
    }

    public static void trySetObservationOutput(String output) {
        Span span = Span.current();
        if (span == null || !span.getSpanContext().isValid()) {
            return;
        }
        span.setAttribute(LangfuseSpanKeys.OBSERVATION_OUTPUT, output == null ? "" : output);
    }

    public static void trySetMetadata(String key, String value) {
        Span span = Span.current();
        if (span == null || !span.getSpanContext().isValid()) {
            return;
        }
        if (key == null || key.isBlank()) {
            return;
        }
        span.setAttribute(LangfuseSpanKeys.METADATA_PREFIX + key, value == null ? "" : value);
    }

    public static void trySetMetadata(String key, long value) {
        Span span = Span.current();
        if (span == null || !span.getSpanContext().isValid()) {
            return;
        }
        if (key == null || key.isBlank()) {
            return;
        }
        span.setAttribute(LangfuseSpanKeys.METADATA_PREFIX + key, value);
    }
}
