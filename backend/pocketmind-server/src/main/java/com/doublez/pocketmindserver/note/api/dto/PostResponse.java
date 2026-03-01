package com.doublez.pocketmindserver.note.api.dto;

import com.doublez.pocketmindserver.note.domain.note.NoteResourceStatus;

import java.util.List;
import java.util.UUID;

/**
 * 客户端轮询读取的帖子对象（notes 表）。
 * assets 列表包含该笔记的所有图片资产（含可直接访问的 URL）。
 * tags 为 AI 分析后写入的标签名称列表。
 */
public record PostResponse(
        UUID uuid,
        String url,
        String aiStatus,
        String summary,
        UUID sessionUuid,
        NoteResourceStatus resourceStatus,
        String previewTitle,
        String previewDescription,
        List<String> tags
) {
}
