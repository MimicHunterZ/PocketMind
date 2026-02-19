package com.doublez.pocketmindserver.shared.domain;

/**
 * 单纯限制返回数量的查询值对象
 */
public record LimitQuery(int limit) {

    public LimitQuery {
        if (limit <= 0) {
            throw new IllegalArgumentException("limit 必须为正数");
        }
    }
}
