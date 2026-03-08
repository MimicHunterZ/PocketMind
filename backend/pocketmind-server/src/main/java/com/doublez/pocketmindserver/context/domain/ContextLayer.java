package com.doublez.pocketmindserver.context.domain;

/**
 * 上下文层级定义。
 * L0 = 极短摘要，L1 = 概览，L2 = 详细正文。
 */
public enum ContextLayer {
    L0_ABSTRACT,
    L1_OVERVIEW,
    L2_DETAIL
}
