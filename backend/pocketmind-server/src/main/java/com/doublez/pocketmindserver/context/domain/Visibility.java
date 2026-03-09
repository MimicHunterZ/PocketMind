package com.doublez.pocketmindserver.context.domain;

/**
 * 上下文对象可见性 — 控制检索与展示边界。
 *
 * <p>配合 {@link SpaceType} 使用，决定对象在检索时可被哪些范围的用户/流程访问。
 *
 * <ul>
 *   <li>{@link #PRIVATE} — 仅 owner 可见（默认）</li>
 *   <li>{@link #SESSION_ONLY} — 仅当前会话内可见，会话结束后不自动进入长期检索</li>
 *   <li>{@link #TENANT_SHARED} — 同租户内所有用户可见</li>
 *   <li>{@link #SYSTEM_SHARED} — 全平台可见（仅限系统对象）</li>
 * </ul>
 */
public enum Visibility {

    /** 仅 owner 可见 — UserMemory、个人 Resource 默认值。 */
    PRIVATE,

    /** 仅当前会话可见 — 会话阶段材料、临时检索结果。 */
    SESSION_ONLY,

    /** 同租户共享 — TenantSkill、组织级模板。 */
    TENANT_SHARED,

    /** 全平台共享 — SharedSkill、平台规则。 */
    SYSTEM_SHARED
}
