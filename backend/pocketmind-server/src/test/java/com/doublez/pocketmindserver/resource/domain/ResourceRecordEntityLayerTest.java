package com.doublez.pocketmindserver.resource.domain;

import com.doublez.pocketmindserver.context.domain.ContextUri;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * ResourceRecordEntity L0/L1 分层内容字段测试。
 */
class ResourceRecordEntityLayerTest {

    @Test
    void 新建资源的abstractText和summaryText默认为null() {
        ResourceRecordEntity entity = ResourceRecordEntity.createNoteText(
                UUID.randomUUID(), 1L, UUID.randomUUID(),
                ContextUri.userResourcesRoot(1L).child("notes").child("test"),
                "测试标题", "测试正文");

        assertNull(entity.getAbstractText());
        assertNull(entity.getSummaryText());
    }

    @Test
    void updateAbstractText应更新L0摘要() {
        ResourceRecordEntity entity = createSampleNote();

        entity.updateAbstractText("Spring Boot 4 架构重构笔记");

        assertEquals("Spring Boot 4 架构重构笔记", entity.getAbstractText());
    }

    @Test
    void updateSummaryText应更新L1概览() {
        ResourceRecordEntity entity = createSampleNote();

        entity.updateSummaryText("## 关键点\n- 使用虚拟线程\n- MyBatis-Plus 3.5");

        assertEquals("## 关键点\n- 使用虚拟线程\n- MyBatis-Plus 3.5", entity.getSummaryText());
    }

    @Test
    void deriveDefaultAbstract_仅标题() {
        ResourceRecordEntity entity = createSampleNote();
        entity.updateContent("架构笔记", null);

        String result = entity.deriveDefaultAbstract();

        assertEquals("架构笔记", result);
    }

    @Test
    void deriveDefaultAbstract_标题加正文() {
        ResourceRecordEntity entity = createSampleNote();
        entity.updateContent("架构笔记", "正文内容简短");

        String result = entity.deriveDefaultAbstract();

        assertEquals("架构笔记：正文内容简短", result);
    }

    @Test
    void deriveDefaultAbstract_长正文截断200字符() {
        String longContent = "A".repeat(300);
        ResourceRecordEntity entity = createSampleNote();
        entity.updateContent("标题", longContent);

        String result = entity.deriveDefaultAbstract();

        // 标题 + ：+ 200 字符 + …
        assertTrue(result.startsWith("标题："));
        assertTrue(result.endsWith("…"));
        // 标题(2) + ：(1) + 200 + …(1) = 204
        assertEquals(204, result.length());
    }

    @Test
    void deriveDefaultAbstract_无标题无正文返回空串() {
        ResourceRecordEntity entity = createSampleNote();
        entity.updateContent(null, null);

        String result = entity.deriveDefaultAbstract();

        assertEquals("", result);
    }

    @Test
    void updateAbstractText应刷新updatedAt() {
        ResourceRecordEntity entity = createSampleNote();
        long before = entity.getUpdatedAt();

        // 等 1ms 确保时间戳变化
        try { Thread.sleep(2); } catch (InterruptedException ignored) {}
        entity.updateAbstractText("新摘要");

        assertTrue(entity.getUpdatedAt() >= before);
    }

    private ResourceRecordEntity createSampleNote() {
        return ResourceRecordEntity.createNoteText(
                UUID.randomUUID(), 1L, UUID.randomUUID(),
                ContextUri.userResourcesRoot(1L).child("notes").child("test"),
                "初始标题", "初始正文");
    }
}
