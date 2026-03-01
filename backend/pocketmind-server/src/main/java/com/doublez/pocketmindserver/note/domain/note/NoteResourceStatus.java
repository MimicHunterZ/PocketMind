package com.doublez.pocketmindserver.note.domain.note;

/**
 * 笔记来源 URL 的抓取状态
 * 状态流转：
 * NONE      — 无来源 URL，无需抓取
 * PENDING   — 有 URL，等待调度
 * FETCHING  — 抓取进行中
 * DONE      — 抓取完成，预览字段已填充
 * FAILED    — 抓取失败，可重试（→ PENDING）
 */
public enum NoteResourceStatus {
    NONE,
    PENDING,
    FETCHING,
    DONE,
    FAILED
}
