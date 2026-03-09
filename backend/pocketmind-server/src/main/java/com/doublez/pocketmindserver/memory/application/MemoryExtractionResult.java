package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.memory.domain.MemoryType;

import java.util.List;

/**
 * LLM 记忆抽取结果。
 *
 * @param memories 抽取到的记忆候选列表
 */
public record MemoryExtractionResult(List<MemoryCandidate> memories) {

    /**
     * 单条记忆候选项。
     */
    public record MemoryCandidate(
            String memoryType,
            String title,
            String abstractText,
            String content,
            String mergeKey
    ) {
        /**
         * 解析记忆类型枚举，无法识别时返回 null。
         */
        public MemoryType resolveMemoryType() {
            try {
                return MemoryType.valueOf(memoryType);
            } catch (IllegalArgumentException e) {
                return null;
            }
        }
    }
}
