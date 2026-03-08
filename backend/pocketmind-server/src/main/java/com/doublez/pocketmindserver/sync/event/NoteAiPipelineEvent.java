package com.doublez.pocketmindserver.sync.event;

import java.util.UUID;

/**
 * 笔记 AI 管线触发事件。
 * <p>
 * 由 {@code SyncServiceImpl} 在接受含有效 URL 的笔记 Push 后通过
 * {@code ApplicationEventPublisher} 发布；AI 管线监听器收到后异步完成
 * 摘要生成并调用 {@code SyncService.persistAiResult} 推进版本号。
 * </p>
 */
public record NoteAiPipelineEvent(UUID noteUuid, long userId) {}
