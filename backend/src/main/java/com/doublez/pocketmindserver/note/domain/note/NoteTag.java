package com.doublez.pocketmindserver.note.domain.note;

/**
 * 值对象：笔记持有的标签关联（通过 tagId 引用 TagEntity 聚合）
 * <p>
 * NoteTag 没有独立生命周期，随 NoteEntity 一同创建和销毁。
 * 聚合间通过 ID 引用，不持有 TagEntity 对象。
 */
public record NoteTag(long tagId) {
}