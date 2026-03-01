package com.doublez.pocketmindserver.shared.domain;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class PageQueryTest {

    @Test
    void shouldComputeOffset() {
        PageQuery q = new PageQuery(20, 3);
        assertEquals(20, q.limit());
        assertEquals(60, q.offset());
    }

    @Test
    void shouldRejectInvalidArgs() {
        assertThrows(IllegalArgumentException.class, () -> new PageQuery(0, 0));
        assertThrows(IllegalArgumentException.class, () -> new PageQuery(10, -1));
    }

    @Test
    void ofShouldRejectExceedingMaxPageSize() {
        // of() 工厂方法应拒绝超过 MAX_PAGE_SIZE 的值
        assertThrows(IllegalArgumentException.class,
                () -> PageQuery.of(PageQuery.MAX_PAGE_SIZE + 1, 0));
        // 边界值：等于 MAX_PAGE_SIZE 应通过
        PageQuery q = PageQuery.of(PageQuery.MAX_PAGE_SIZE, 0);
        assertEquals(PageQuery.MAX_PAGE_SIZE, q.pageSize());
    }

    @Test
    void unboundedShouldAllowLargePageSize() {
        // unbounded() 不受 MAX_PAGE_SIZE 限制
        PageQuery q = PageQuery.unbounded(1000);
        assertEquals(1000, q.pageSize());
        assertEquals(0, q.pageIndex());
    }
}
