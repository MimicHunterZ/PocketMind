package com.doublez.pocketmindserver.note.api.dto;

import com.doublez.pocketmindserver.note.domain.note.NoteResourceStatus;

import java.util.UUID;

/**
 * 客户端轮询读取的帖子对象（notes 表）。
 */
public record PostResponse(
        UUID uuid,
        String url,
        String aiStatus,
        String summary,
        UUID sessionUuid,
        NoteResourceStatus resourceStatus,
        String previewTitle,
        String previewDescription
) {
}
