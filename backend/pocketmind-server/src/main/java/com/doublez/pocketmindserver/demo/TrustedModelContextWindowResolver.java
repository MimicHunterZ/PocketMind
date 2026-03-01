package com.doublez.pocketmindserver.demo;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/**
 * demo 专用：模型上下文窗口解析器。
 *
 * 这里不做任何网络请求，也不做“可信源抓取”。原因：
 * 1) demo 的目标是验证“上下文评估/观测链路”，不应该引入外部网络不确定性。
 * 2) 真实项目里可以再接入配置中心/模型注册表，这里先按 yml 字段映射读取。
 */
public class TrustedModelContextWindowResolver {

    private final int defaultWindowTokens;
    private final Map<String, Integer> overrides;
    private final Map<String, Integer> normalizedOverrides;

    public TrustedModelContextWindowResolver(int defaultWindowTokens, Map<String, Integer> overrides) {
        this.defaultWindowTokens = defaultWindowTokens;
        this.overrides = overrides == null ? Collections.emptyMap() : overrides;

        // 为了避免模型名大小写/别名导致查不到配置，这里构建一份“归一化 key”的索引。
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

    /**
     * 解析模型窗口大小（token）。
        * 优先级：yml 覆盖 > 默认值。
     */
    public int resolveWindowTokens(String modelName) {
        if (modelName == null || modelName.isBlank()) {
            return defaultWindowTokens;
        }

        Integer configured = overrides.get(modelName);
        if (configured != null && configured > 0) {
            return configured;
        }

        // 兼容：deepseek-chat vs DeepSeek-Chat / provider 前缀等。
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

        // 常见情况：某些 provider 会用类似 "provider/model" 或 "provider:model" 的格式。
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
