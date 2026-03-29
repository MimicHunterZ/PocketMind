package com.doublez.pocketmindserver.context.domain;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * ContextNode 领域对象单测。
 */
class ContextNodeTest {

    private static final java.util.UUID RESOURCE_UUID = java.util.UUID.fromString("11111111-1111-4111-8111-111111111111");

    @Test
    void 基础字段可正常构造() {
        ContextNode node = new ContextNode(
                ContextUri.of("pm://users/1/resources/note-1"),
                RESOURCE_UUID,
                ContextType.RESOURCE,
                "测试笔记",
                "笔记摘要",
                0L, System.currentTimeMillis());

        assertThat(node.resourceUuid()).isEqualTo(RESOURCE_UUID);
        assertThat(node.name()).isEqualTo("测试笔记");
    }

    @Test
    void 必须有uri() {
        assertThatThrownBy(() -> new ContextNode(
                null, RESOURCE_UUID, ContextType.RESOURCE,
                "test", null, 0L, 0L))
                .isInstanceOf(NullPointerException.class);
    }

    @Test
    void 必须有resourceUuid() {
        ContextNode node = new ContextNode(
                ContextUri.of("pm://users/1/resources/notes"),
                RESOURCE_UUID,
                ContextType.RESOURCE,
                "笔记目录",
                "所有用户笔记",
                0L, System.currentTimeMillis());

        assertThatThrownBy(() -> new ContextNode(
                ContextUri.of("pm://users/1/resources/notes"),
                null,
                ContextType.RESOURCE,
                "笔记目录",
                "所有用户笔记",
                0L,
                System.currentTimeMillis()))
                .isInstanceOf(NullPointerException.class);
    }

    @Test
    void 必须有contextType() {
        ContextNode node = new ContextNode(
                ContextUri.of("pm://users/1/memories/profile"),
                RESOURCE_UUID,
                ContextType.MEMORY,
                "用户画像",
                "用户偏好概览",
                5L, System.currentTimeMillis());

        assertThatThrownBy(() -> new ContextNode(
                ContextUri.of("pm://test"), RESOURCE_UUID, null,
                "test", null, 0L, 0L))
                .isInstanceOf(NullPointerException.class);
    }

    @Test
    void 允许空摘要与基础计数() {
        ContextNode node = new ContextNode(
                ContextUri.of("pm://users/1/resources/orphan"),
                RESOURCE_UUID,
                ContextType.RESOURCE,
                "孤儿节点",
                null,
                0L,
                0L);

        assertThat(node.abstractText()).isNull();
        assertThat(node.activeCount()).isZero();
    }
}
