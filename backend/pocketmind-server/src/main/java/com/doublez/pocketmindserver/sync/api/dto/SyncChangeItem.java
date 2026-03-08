package com.doublez.pocketmindserver.sync.api.dto;

import java.util.Map;

/**
 *
 * @param entityType   实体类型：'note' | 'category'
 * @param uuid         业务实体 UUID 字符串
 * @param operation    操作类型：'create' | 'update' | 'delete'
 * @param serverVersion 本条变更对应的 sync_change_log.id（服务端版本号）
 * @param updatedAt    业务实体 updatedAt 毫秒时间戳，作为客户端 LWW 裁决依据
 * @param payload      实体完整字段 map；delete 操作时为空 map
 */
public record SyncChangeItem(
        String entityType,
        String uuid,
        String operation,
        long serverVersion,
        long updatedAt,
        Map<String, Object> payload
) {}
