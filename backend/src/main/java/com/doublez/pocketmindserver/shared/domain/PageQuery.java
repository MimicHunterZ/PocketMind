package com.doublez.pocketmindserver.shared.domain;

/**
 * 分页查询值对象（领域层使用，避免暴露数据库 offset/limit 细节）
 */
public record PageQuery(int pageSize, int pageIndex) {

    public PageQuery {
        if (pageSize <= 0) {
            throw new IllegalArgumentException("pageSize 必须为正数");
        }
        if (pageIndex < 0) {
            throw new IllegalArgumentException("pageIndex 不能为负数");
        }
    }

    public int limit() {
        return pageSize;
    }

    public int offset() {
        return pageIndex * pageSize;
    }
}
