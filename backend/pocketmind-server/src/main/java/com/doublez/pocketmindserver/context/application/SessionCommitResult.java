package com.doublez.pocketmindserver.context.application;

import java.util.UUID;

/**
 * 会话提交结果。
 *
 * @param sessionUuid           提交的会话 UUID
 * @param transcriptResourceUuid 对话转录资源 UUID
 * @param summaryResourceUuid    阶段摘要资源 UUID
 * @param messageCount           参与摘要的消息数量
 * @param abstractText           L0 一句话摘要
 */
public record SessionCommitResult(
        UUID sessionUuid,
        UUID transcriptResourceUuid,
        UUID summaryResourceUuid,
        int messageCount,
        String abstractText
) {
}
