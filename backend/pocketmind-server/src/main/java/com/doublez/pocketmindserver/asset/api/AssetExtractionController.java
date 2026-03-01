package com.doublez.pocketmindserver.asset.api;

import com.doublez.pocketmindserver.asset.application.AssetExtractionsService;
import com.doublez.pocketmindserver.asset.api.dto.AssetExtractionsResponse;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * assets 鍐呭鎻愬彇缁撴灉杞鎺ュ彛銆?
 *
 * 鍥剧墖涓婁紶鍚庯紝瑙嗚鍒嗘瀽锛圴isionWorker锛夊紓姝ュ啓鍏?asset_extractions 琛ㄣ€?
 * 瀹㈡埛绔€氳繃姝ゆ帴鍙ｈ疆璇?
 */
@Slf4j
@RestController
@RequestMapping("/api/assets/extractions")
@RequiredArgsConstructor
public class AssetExtractionController {

    private final AssetExtractionsService assetExtractionsService;


    /**
     * 鏌ヨ鎸囧畾绗旇鐨?AI 鎻愬彇缁撴灉锛堟墍鏈夌姸鎬侊級銆?
     *
     * @param assetsUuid UUID
     * @return 鎻愬彇鍐呭鍒楄〃
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
            throw new BusinessException(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "闈炴硶 userId");
        }
    }
}

