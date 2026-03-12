package com.doublez.pocketmindserver.ai.application.retrieval;

/**
 * 类型化检索查询 — LLM 意图分析产出的单条检索指令。
 *
 * @param query       检索文本
 * @param contextType 上下文类型（resource / memory）
 * @param intent      查询目的描述
 * @param priority    优先级（1=最高，5=最低）
 */
public record TypedQuery(
        String query,
        String contextType,
        String intent,
        int priority
) implements Comparable<TypedQuery> {

    @Override
    public int compareTo(TypedQuery other) {
        return Integer.compare(this.priority, other.priority);
    }
}
