package com.doublez.pocketmindserver.memory.domain;

/**
 * 长期记忆分类 — 对齐 OpenViking 8 类。
 *
 * <p>USER 空间：PROFILE / PREFERENCES / ENTITIES / EVENTS
 * <p>AGENT 空间：CASES / PATTERNS / TOOL_EXPERIENCE / SKILL_EXECUTION
 */
public enum MemoryType {
    // ── USER 空间 ──
    PROFILE,
    PREFERENCES,
    ENTITIES,
    EVENTS,
    // ── AGENT 空间 ──
    CASES,
    PATTERNS,
    TOOL_EXPERIENCE,
    SKILL_EXECUTION
}
