package com.doublez.pocketmindserver.sync.api.dto;

import java.util.List;

/**
 * Pull 接口响应体，字段命名与 Flutter {@code SyncPullResponse.fromJson} 严格对齐。
 *
 * @param serverVersion 本批次最大的 sync_change_log.id，客户端下次请求的 sinceVersion；
 *                      若 changes 为空则返回传入的 sinceVersion，游标不推进
 * @param hasMore       是否还有更多数据（用于客户端分页循环）
 * @param changes       增量变更列表，按 serverVersion 升序排列
 */
public record SyncPullResponse(
        long serverVersion,
        boolean hasMore,
        List<SyncChangeItem> changes
) {}
