package com.doublez.pocketmindserver.shared.domain;

/**
 * 分页查询值对象（领域层使用，避免暴露数据库 offset/limit 细节）。
 * <p>外部 API 入口使用默认构造器，pageSize 上限为 {@value #MAX_PAGE_SIZE}，防止恶意大页查询。
 * 内部全量加载场景使用 {@link #unbounded(int)} 工厂方法，跳过大小限制。
 */
public record PageQuery(int pageSize, int pageIndex) {

    /** 单次查询允许的最大页大小（外部 API） */
    public static final int MAX_PAGE_SIZE = 200;

    public PageQuery {
        if (pageSize <= 0) {
            throw new IllegalArgumentException("pageSize 必须为正数");
        }
        if (pageIndex < 0) {
            throw new IllegalArgumentException("pageIndex 不能为负数");
        }
    }

    /**
     * 面向外部 API 的安全构造：强制 pageSize 不超过 {@value #MAX_PAGE_SIZE}。
     */
    public static PageQuery of(int pageSize, int pageIndex) {
        if (pageSize > MAX_PAGE_SIZE) {
            throw new IllegalArgumentException("pageSize 不能超过 " + MAX_PAGE_SIZE);
        }
        return new PageQuery(pageSize, pageIndex);
    }

    /**
     * 内部全量加载场景（如分支分析），不受 MAX_PAGE_SIZE 限制。
     */
    public static PageQuery unbounded(int pageSize) {
        return new PageQuery(pageSize, 0);
    }

    public int limit() {
        return pageSize;
    }

    public int offset() {
        return pageIndex * pageSize;
    }
}
