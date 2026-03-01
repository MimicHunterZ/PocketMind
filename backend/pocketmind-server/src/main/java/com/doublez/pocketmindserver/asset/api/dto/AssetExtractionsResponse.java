package com.doublez.pocketmindserver.asset.api.dto;

import java.util.List;

/**
 * 笔记资产提取轮询响应。
 * 客户端轮询 GET /api/assets/extractions/{noteUuid} 时返回此结构。
 *
 * hasPending = true 时说明仍有提取任务在处理中，客户端继续轮询；
 * hasPending = false 时说明全部结束（DONE 或 FAILED），可写库并停止轮询。
 */
public record AssetExtractionsResponse(
        List<AssetExtractionDTO> extractions
) {
}
