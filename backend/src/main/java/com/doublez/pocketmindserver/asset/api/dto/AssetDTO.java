package com.doublez.pocketmindserver.asset.api.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * 资产元数据 DTO，供客户端查询和渲染使用。
 * url 为可直接访问的图片下载地址：{baseUrl}/api/assets/images/{uuid}
 */
public record AssetDTO(
        UUID uuid,
        String mime,
        int width,
        int height,
        String type,
        Long size,
        String fileName,
        String storageType,
        int sortOrder,
        Instant createdAt
) {
}
