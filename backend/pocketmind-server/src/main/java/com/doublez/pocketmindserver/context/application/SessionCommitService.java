package com.doublez.pocketmindserver.context.application;

import java.util.UUID;

/**
 * 会话提交服务 — 将完成的对话"提交"到上下文体系。
 *
 * <p>核心流程：
 * <ol>
 *   <li>加载会话及消息</li>
 *   <li>确保对话转录 Resource 已同步</li>
 *   <li>调用 LLM 生成结构化摘要（L0 abstractText + L1 summaryText）</li>
 *   <li>创建 CHAT_STAGE_SUMMARY Resource 并同步到 context_catalog</li>
 *   <li>创建 ContextRef 关联</li>
 *   <li>递增 context_catalog 热度计数</li>
 * </ol>
 */
public interface SessionCommitService {

    /**
     * 提交指定会话，生成阶段摘要并同步到上下文体系。
     *
     * @param userId      用户 ID
     * @param sessionUuid 会话 UUID
     * @return 提交结果
     */
    SessionCommitResult commit(long userId, UUID sessionUuid);
}
