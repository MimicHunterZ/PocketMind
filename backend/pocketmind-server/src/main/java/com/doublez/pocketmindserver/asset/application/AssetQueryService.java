package com.doublez.pocketmindserver.asset.application;

import com.doublez.pocketmindserver.asset.api.dto.AssetDTO;
import com.doublez.pocketmindserver.asset.domain.Asset;
import com.doublez.pocketmindserver.asset.domain.AssetRepository;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 璧勪骇鏌ヨ涓庣粦瀹氭湇鍔°€?
 *
 * <p>涓昏鍔熻兘锛?
 * <ul>
 *   <li>鎸夌瑪璁版煡璇㈣祫浜у垪琛紙鍚彲璁块棶鐨勫浘鐗?URL锛?/li>
 *   <li>灏嗗绔嬭祫浜х粦瀹氬埌鎸囧畾绗旇锛堝厛涓婁紶鍚庣粦瀹氬満鏅級</li>
 * </ul>
 * </p>
 */
@Slf4j
@Service
public class AssetQueryService {

    private final AssetRepository assetRepository;

    public AssetQueryService(AssetRepository assetRepository) {
        this.assetRepository = assetRepository;
    }

    /**
     * 鏌ヨ鎸囧畾绗旇涓嬬殑鎵€鏈夎祫浜э紝骞舵嫾鎺ュ彲璁块棶鐨勪笅杞?URL銆?
     *
     * @param noteUuid 绗旇 UUID
     * @param userId   褰撳墠鐢ㄦ埛 ID锛堟潈闄愰殧绂伙級
     * @return 璧勪骇 DTO 鍒楄〃
     */
    public List<AssetDTO> listByNote(UUID noteUuid, long userId) {
        List<Asset> assets = assetRepository.findByNoteUuidAndUserId(noteUuid, userId);
        return assets.stream()
                .map(this::toDto)
                .toList();
    }

    /**
     * 灏嗘寚瀹氳祫浜х粦瀹氬埌绗旇锛屽悓鏃舵牎楠屾墍鏈夋潈銆?
     *
     * @param assetUuid 璧勪骇 UUID
     * @param userId    褰撳墠鐢ㄦ埛 ID
     * @param noteUuid  鐩爣绗旇 UUID
     */
    public void bindToNote(UUID assetUuid, long userId, UUID noteUuid) {
        // 鏍￠獙璧勪骇褰掑睘
        assetRepository.findByUuidAndUserId(assetUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND,
                        HttpStatus.NOT_FOUND,
                        "璧勪骇涓嶅瓨鍦ㄦ垨鏃犳潈闄? uuid=" + assetUuid));

        boolean updated = assetRepository.bindNoteUuid(assetUuid, userId, noteUuid);
        if (!updated) {
            throw new BusinessException(
                    ApiCode.ATTACHMENT_SAVE_FAILED,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "缁戝畾澶辫触: assetUuid=" + assetUuid);
        }
        log.info("[AssetQueryService] 璧勪骇缁戝畾鎴愬姛: assetUuid={}, noteUuid={}", assetUuid, noteUuid);
    }

    /** 灏?Asset 瀹炰綋杞负 DTO锛屽楂樹粠 metadata JSONB 涓鍙栥€?*/
    private AssetDTO toDto(Asset asset) {
        int width = 0;
        int height = 0;
        Map<String, Object> meta = asset.getMetadata();
        if (meta != null) {
            Object w = meta.get("width");
            Object h = meta.get("height");
            if (w instanceof Number n) width = n.intValue();
            if (h instanceof Number n) height = n.intValue();
        }
        return new AssetDTO(asset.getUuid(), asset.getMime(), width, height
                ,asset.getType(), asset.getSize(),asset.getFileName(),asset.getStorageType(),
                asset.getSortOrder() != null ? asset.getSortOrder() : 0,
                asset.getCreatedAt());
    }
}

