package com.doublez.pocketmindserver.ai.observability.langfuse;

/**
 * Langfuse OTel 集成使用的 span attribute key。
 */
public final class LangfuseSpanKeys {

    private LangfuseSpanKeys() {
    }

    public static final String OBSERVATION_INPUT = "langfuse.observation.input";
    public static final String OBSERVATION_OUTPUT = "langfuse.observation.output";

    public static final String METADATA_PREFIX = "langfuse.observation.metadata.";
}
