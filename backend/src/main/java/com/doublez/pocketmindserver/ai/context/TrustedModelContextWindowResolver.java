package com.doublez.pocketmindserver.ai.context;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/**
 * 业务侧：模型上下文窗口解析器。
 */
public class TrustedModelContextWindowResolver {

    private final int defaultWindowTokens;
    private final Map<String, Integer> overrides;
    private final Map<String, Integer> normalizedOverrides;

    public TrustedModelContextWindowResolver(int defaultWindowTokens, Map<String, Integer> overrides) {
        this.defaultWindowTokens = defaultWindowTokens;
        this.overrides = overrides == null ? Collections.emptyMap() : overrides;

        Map<String, Integer> normalized = new HashMap<>();
        for (Map.Entry<String, Integer> entry : this.overrides.entrySet()) {
            if (entry == null || entry.getKey() == null) {
                continue;
            }
            String key = normalizeModelName(entry.getKey());
            Integer value = entry.getValue();
            if (key != null && !key.isBlank() && value != null && value > 0) {
                normalized.putIfAbsent(key, value);
            }
        }
        this.normalizedOverrides = Collections.unmodifiableMap(normalized);
    }

    public int resolveWindowTokens(String modelName) {
        if (modelName == null || modelName.isBlank()) {
            return defaultWindowTokens;
        }

        Integer configured = overrides.get(modelName);
        if (configured != null && configured > 0) {
            return configured;
        }

        String normalized = normalizeModelName(modelName);
        if (normalized != null) {
            Integer normalizedConfigured = normalizedOverrides.get(normalized);
            if (normalizedConfigured != null && normalizedConfigured > 0) {
                return normalizedConfigured;
            }
        }
        return defaultWindowTokens;
    }

    private String normalizeModelName(String modelName) {
        if (modelName == null) {
            return null;
        }
        String trimmed = modelName.trim();
        if (trimmed.isEmpty()) {
            return null;
        }

        String candidate = trimmed;
        int slash = candidate.lastIndexOf('/');
        if (slash >= 0 && slash + 1 < candidate.length()) {
            candidate = candidate.substring(slash + 1);
        }
        int colon = candidate.lastIndexOf(':');
        if (colon >= 0 && colon + 1 < candidate.length()) {
            candidate = candidate.substring(colon + 1);
        }

        return candidate.toLowerCase();
    }
}
