package com.doublez.pocketmindserver.asset.api;

import com.doublez.pocketmindserver.asset.application.AssetExtractionsService;
import com.doublez.pocketmindserver.asset.api.dto.AssetExtractionsResponse;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * assets 内容提取结果轮询接口。
 *
 * 图片上传后，视觉分析（VisionWorker）异步写入 asset_extractions 表。
 * 客户端通过此接口轮询.
 */
@Slf4j
@RestController
@RequestMapping("/api/assets/extractions")
@RequiredArgsConstructor
public class AssetExtractionController {

    private final AssetExtractionsService assetExtractionsService;


    /**
     * 查询指定笔记的 AI 提取结果（所有状态）。
     *
     * @param assetsUuid UUID
     * @return 提取内容列表
     */
    @GetMapping("/{assetsUuid}")
    public AssetExtractionsResponse getExtractions(
            @PathVariable("assetsUuid") UUID assetsUuid) {
        long userId = parseUserId(UserContext.getRequiredUserId());

        return assetExtractionsService
                .getAssetsExtractions(userId, assetsUuid);
    }

    private long parseUserId(String userId) {
        try {
            return Long.parseLong(userId);
        } catch (NumberFormatException e) {
            throw new BusinessException(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "非法 userId");
        }
    }
}
