package com.doublez.pocketmindserver.context.domain;

/**
 * 上下文空间类型 — 五层空间模型。
 *
 * <p>每个上下文对象都归属于一个空间，空间决定隔离粒度和可见性范围：
 * <ul>
 *   <li>{@link #SYSTEM} — 全局共享：平台规则、SharedSkill</li>
 *   <li>{@link #TENANT} — 租户级：TenantSkill、组织模板</li>
 *   <li>{@link #AGENT} — 智能体级：AgentMemory(CASE/PATTERN)、AgentOverlay</li>
 *   <li>{@link #USER} — 用户级：UserMemory、Resource、Note</li>
 *   <li>{@link #SESSION} — 会话级：当前轮次材料、临时检索结果</li>
 * </ul>
 */
public enum SpaceType {

    /** 系统空间 — 归属 system，全平台共享。 */
    SYSTEM,

    /** 租户空间 — 归属 tenantId，组织内共享。 */
    TENANT,

    /** 智能体空间 — 归属 agentKey，存储执行经验。 */
    AGENT,

    /** 用户空间 — 归属 userId，个人私有。 */
    USER,

    /** 会话空间 — 归属 userId + sessionId，会话结束后按策略处理。 */
    SESSION
}
