package com.doublez.pocketmindserver.ai.application.retrieval;

/**
 * 标准化检索片段 — Resource / Memory 双通道的统一输出格式。
 *
 * <p>由 {@link RetrievalOrchestrator} 汇总后供 ContextAssembler 消费。
 *
 * @param uri          上下文 URI（pm:// 格式）
 * @param title        标题
 * @param abstractText 摘要（L0/L1 层，可为空）
 * @param content      完整内容（L2 层，可为空）
 * @param score        综合得分（0.0–1.0）
 * @param source       来源通道
 */
public record ContextSnippet(
        String uri,
        String title,
        String abstractText,
        String content,
        double score,
        SnippetSource source
) implements Comparable<ContextSnippet> {

    /**
     * 按分数降序排列。
     */
    @Override
    public int compareTo(ContextSnippet other) {
        return Double.compare(other.score, this.score);
    }
}
