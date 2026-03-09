package com.doublez.pocketmindserver.context.domain;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * ContextNode 领域对象单测。
 */
class ContextNodeTest {

    @Test
    void L2叶子节点视为终端() {
        ContextNode node = new ContextNode(
                ContextUri.of("pm://users/1/resources/note-1"),
                ContextUri.userResourcesRoot(1L),
                ContextType.RESOURCE,
                ContextLayer.L2_DETAIL,
                "测试笔记",
                "笔记摘要",
                0L, System.currentTimeMillis(), true);

        assertThat(node.isTerminal()).isTrue();
        assertThat(node.isDirectory()).isFalse();
    }

    @Test
    void L0目录节点非终端() {
        ContextNode node = new ContextNode(
                ContextUri.of("pm://users/1/resources/notes"),
                ContextUri.userResourcesRoot(1L),
                ContextType.RESOURCE,
                ContextLayer.L0_ABSTRACT,
                "笔记目录",
                "所有用户笔记",
                0L, System.currentTimeMillis(), false);

        assertThat(node.isTerminal()).isFalse();
        assertThat(node.isDirectory()).isTrue();
    }

    @Test
    void L1概览目录非终端() {
        ContextNode node = new ContextNode(
                ContextUri.of("pm://users/1/memories/profile"),
                ContextUri.userMemoriesRoot(1L),
                ContextType.MEMORY,
                ContextLayer.L1_OVERVIEW,
                "用户画像",
                "用户偏好概览",
                5L, System.currentTimeMillis(), false);

        assertThat(node.isTerminal()).isFalse();
    }

    @Test
    void 叶子节点即使L0也视为终端() {
        ContextNode node = new ContextNode(
                ContextUri.of("pm://users/1/resources/orphan"),
                null,
                ContextType.RESOURCE,
                ContextLayer.L0_ABSTRACT,
                "孤儿节点",
                null,
                0L, 0L, true); // isLeaf=true

        assertThat(node.isTerminal()).isTrue();
    }

    @Test
    void 必须有uri() {
        assertThatThrownBy(() -> new ContextNode(
                null, null, ContextType.RESOURCE, ContextLayer.L2_DETAIL,
                "test", null, 0L, 0L, true))
                .isInstanceOf(NullPointerException.class);
    }

    @Test
    void 必须有contextType() {
        assertThatThrownBy(() -> new ContextNode(
                ContextUri.of("pm://test"), null, null, ContextLayer.L2_DETAIL,
                "test", null, 0L, 0L, true))
                .isInstanceOf(NullPointerException.class);
    }

    @Test
    void 必须有layer() {
        assertThatThrownBy(() -> new ContextNode(
                ContextUri.of("pm://test"), null, ContextType.RESOURCE, null,
                "test", null, 0L, 0L, true))
                .isInstanceOf(NullPointerException.class);
    }
}
