package com.doublez.pocketmindserver.memory.application;

import com.doublez.pocketmindserver.context.application.SessionCommitResult;

import java.util.UUID;

/**
 * 记忆抽取器接口 — 从对话摘要中抽取记忆候选项并持久化。
 */
public interface MemoryExtractorService {

    /**
     * 从 SessionCommit 结果触发记忆抽取。
     *
     * @param userId        用户 ID
     * @param sessionUuid   会话 UUID
     * @param commitResult  会话提交结果（含摘要内容）
     * @return 新增的记忆数量
     */
    int extractFromCommit(long userId, UUID sessionUuid, SessionCommitResult commitResult);
}
