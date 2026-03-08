package com.doublez.pocketmindserver.resource.application;

import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import org.junit.jupiter.api.Test;

import java.util.Collections;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * NoteResourceProjectionService 投影测试。
 */
class NoteResourceProjectionServiceTest {

    private final NoteResourceProjectionService service = new NoteResourceProjectionServiceImpl(new ResourceContextServiceImpl());

    @Test
    void shouldProjectPlainNoteToNoteTextResource() {
        NoteEntity note = new NoteEntity(
                UUID.randomUUID(),
                11L,
                "我的想法",
                "今天记录一些纯文本内容",
                null,
                1L,
                Collections.emptyList(),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                System.currentTimeMillis(),
                false,
                null
        );

        ResourceRecordEntity resource = service.projectNoteText(note);

        assertEquals(ResourceSourceType.NOTE_TEXT, resource.getSourceType());
        assertEquals(note.getUuid(), resource.getNoteUuid());
        assertEquals("我的想法", resource.getTitle());
        assertEquals("今天记录一些纯文本内容", resource.getContent());
    }

    @Test
    void shouldProjectSharedNoteToWebClipResource() {
        NoteEntity note = new NoteEntity(
                UUID.randomUUID(),
                22L,
                null,
                null,
                "https://example.com/post/2",
                1L,
                Collections.emptyList(),
                null,
                "帖子标题",
                "帖子描述",
                "帖子正文",
                null,
                "总结",
                null,
                System.currentTimeMillis(),
                false,
                null
        );

        ResourceRecordEntity resource = service.projectWebClip(note);

        assertEquals(ResourceSourceType.WEB_CLIP, resource.getSourceType());
        assertEquals(note.getUuid(), resource.getNoteUuid());
        assertEquals("https://example.com/post/2", resource.getSourceUrl());
        assertEquals("帖子标题", resource.getTitle());
        assertEquals("帖子正文", resource.getContent());
    }
}
