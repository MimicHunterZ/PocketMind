package com.doublez.pocketmindserver.resource.application.mq;

import java.util.UUID;

/**
 * Resource 索引 Outbox Hint 事件。
 *
 * @param eventUuid       对应 outbox 事件 UUID
 * @param userId          用户 ID
 * @param resourceUuid    资源 UUID
 * @param operation       操作类型（upsert/delete）
 * @param occurredAt      发生时间戳（毫秒）
 */
public record ResourceOutboxHintEvent(
        UUID eventUuid,
        long userId,
        UUID resourceUuid,
        String operation,
        long occurredAt
) {
}
