package com.doublez.pocketmindserver.shared.domain;

/**
 * 增量同步游标查询值对象
 */
public record SyncCursorQuery(long cursor, int limit) {

    public SyncCursorQuery {
        if (limit <= 0) {
            throw new IllegalArgumentException("limit 必须为正数");
        }
    }
}
