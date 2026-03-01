package com.doublez.pocketmindserver.ai.context;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.Map;

/**
 * 上下文工程：工具结果（ToolResponseMessage）剪枝相关配置（业务侧）。
 *
 * 说明：该配置是业务侧能力，不能与 demo 的 pocketmind.demo.* 混用。
 */
@ConfigurationProperties(prefix = "pocketmind.context-engineering.tool-result")
public record ToolResultContextEngineeringProperties(
        boolean enabled,
        double compressStartRatio,
        int keepRecentToolResponses,
        int defaultWindowTokens,
    /**
     * 模型上下文窗口（token）覆盖：推荐使用 yml map 配置。
     *
     * 示例：
     * pocketmind.context-engineering.tool-result.model-window-tokens.deepseek-chat: 64000
     */
    Map<String, Integer> modelWindowTokens
) {

    public ToolResultContextEngineeringProperties {
        if (compressStartRatio <= 0) {
            compressStartRatio = 0.75;
        }
        if (keepRecentToolResponses <= 0) {
            keepRecentToolResponses = 2;
        }
        if (defaultWindowTokens <= 0) {
            defaultWindowTokens = 64000;
        }
        if (modelWindowTokens == null) {
            modelWindowTokens = Map.of();
        }
    }
}
