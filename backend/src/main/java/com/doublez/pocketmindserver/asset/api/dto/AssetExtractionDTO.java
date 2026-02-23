package com.doublez.pocketmindserver.asset.api.dto;

import java.util.UUID;

/**
 * 资产内容提取结果 DTO。
 * 对应 asset_extractions 表中的记录。
 * 用于独立轮询端点（GET /api/assets/extractions/{noteUuid}），不包含在 PostResponse 中。
 * status 可取 PENDING / DONE / FAILED，content 在 PENDING 时为 null。
 */
public record AssetExtractionDTO(
        UUID assetUuid,
        String contentType,
        String content,
        String model,
        String status
) {
}
