package com.doublez.pocketmindserver.sync.api.dto;

import java.util.List;

/**
 * 拉取同步响应
 */
public record SyncPullResponse(
        /** 本次响应的最新游标（毫秒时间戳），客户端下次从此游标继续拉取 */
        long cursor,
        /** 是否还有更多数据 */
        boolean hasMore,
        /** 变更条目列表 */
        List<SyncChangeItem> changes
) {}
