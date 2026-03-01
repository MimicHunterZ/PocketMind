package com.doublez.pocketmindserver.asset.application;

import com.doublez.pocketmindserver.asset.domain.Asset;
import com.doublez.pocketmindserver.asset.domain.AssetRepository;
import com.doublez.pocketmindserver.asset.spi.AssetStore;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.ResourceRegion;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.util.UUID;
import java.util.concurrent.TimeUnit;

/**
 * 鍥剧墖鍒嗗彂涓氬姟鏈嶅姟銆?
 *
 * <p>鏀寔涓ょ鍝嶅簲妯″紡锛?
 * <ul>
 *   <li><b>HTTP 200</b>锛氭棤 Range 璇锋眰澶达紝閫氳繃 Spring {@link Resource} 鍏ㄩ噺杩斿洖鍥剧墖銆?/li>
 *   <li><b>HTTP 206</b>锛氭湁 Range 璇锋眰澶达紝閫氳繃 {@link ResourceRegion} 杩斿洖鎸囧畾瀛楄妭娈碉紝
 *       瀹岀編鏀寔鏂偣缁紶/澶у浘鍒嗗潡鍔犺浇锛屽悓鏃朵负鏈潵 S3 鍒嗘 GetObject 棰勭暀鏋舵瀯鎺ュ彛銆?/li>
 * </ul>
 * </p>
 *
 * <p><b>瀹夊叏杈圭晫</b>锛氭墍鏈夎姹傚繀椤婚檮甯?userId锛岄€氳繃 DB 鏌ヨ楠岃瘉闄勪欢褰掑睘锛屾潨缁濊秺鏉冭闂€?/p>
 */
@Slf4j
@Service
public class ImageServeService {

    /** 闀跨紦瀛樼瓥鐣ワ細绉佹湁缂撳瓨 1 骞淬€傚浘鐗囧唴瀹逛笉鍙彉锛圲UID 鍞竴锛夛紝瀹夊叏浣跨敤闀跨紦瀛樸€?*/
    private static final CacheControl CACHE_CONTROL =
            CacheControl.maxAge(365, TimeUnit.DAYS).cachePrivate();

    private final AssetStore assetStore;
    private final AssetRepository AssetRepository;

    public ImageServeService(AssetStore assetStore, AssetRepository AssetRepository) {
        this.assetStore = assetStore;
        this.AssetRepository = AssetRepository;
    }

    /**
     * 杩斿洖瀹屾暣鍥剧墖璧勬簮锛圚TTP 200锛夈€?
     *
     * @param attachmentUuid 闄勪欢 UUID锛堟潵鑷?URL 璺緞锛?
     * @param userId         褰撳墠鐧诲綍鐢ㄦ埛 ID锛堢敤浜庤秺鏉冩牎楠岋級
     * @return 鍖呭惈 Content-Type 鍜?Cache-Control 澶寸殑 200 鍝嶅簲
     */
    public ResponseEntity<Resource> serveFullImage(UUID attachmentUuid, long userId) {
        Asset attachment = requireOwnedAsset(attachmentUuid, userId);
        Resource resource = assetStore.getResource(String.valueOf(userId), attachment.getStorageKey());

        log.debug("[ImageServe] 200 鍏ㄩ噺鍝嶅簲: uuid={}, key={}", attachmentUuid, attachment.getStorageKey());

        return ResponseEntity.ok()
                .contentType(resolveMediaType(attachment.getMime()))
                .cacheControl(CACHE_CONTROL)
                .body(resource);
    }

    /**
     * 杩斿洖鍥剧墖鐨勬寚瀹氬瓧鑺傝寖鍥达紙HTTP 206锛夛紝鏀寔鏂偣缁紶銆?
     *
     * <p>閫氳繃 Spring 鍘熺敓 {@link ResourceRegion} + {@code ResourceRegionMessageConverter} 瀹炵幇锛?
     * 搴曞眰鑷姩澶勭悊瀛楄妭鍐欏叆锛屽簲鐢ㄥ眰闆?Copy 寮€閿€銆?/p>
     *
     * @param attachmentUuid 闄勪欢 UUID
     * @param userId         褰撳墠鐧诲綍鐢ㄦ埛 ID
     * @param requestHeaders 鏉ヨ嚜瀹㈡埛绔殑璇锋眰澶达紙鍐呭惈 Range 淇℃伅锛?
     * @return 206 Partial Content 鍝嶅簲
     */
    public ResponseEntity<ResourceRegion> servePartialImage(
            UUID attachmentUuid, long userId, HttpHeaders requestHeaders) {

        Asset attachment = requireOwnedAsset(attachmentUuid, userId);
        ResourceRegion region = assetStore.createResourceRegion(
                String.valueOf(userId), attachment.getStorageKey(), requestHeaders);

        log.debug("[ImageServe] 206 鍒嗘鍝嶅簲: uuid={}, position={}, count={}",
                attachmentUuid, region.getPosition(), region.getCount());

        return ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
                .contentType(resolveMediaType(attachment.getMime()))
                .cacheControl(CACHE_CONTROL)
                .body(region);
    }

    /**
     * 浠?DB 鏌ヨ闄勪欢骞舵牎楠屽綊灞炴潈锛堣秺鏉冮槻寰★級銆?
     * 鑻ラ檮浠朵笉瀛樺湪鎴栦笉灞炰簬璇ョ敤鎴凤紝鎶涘嚭 404 BusinessException銆?
     */
    private Asset requireOwnedAsset(UUID attachmentUuid, long userId) {
        return AssetRepository.findByUuidAndUserId(attachmentUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND,
                        HttpStatus.NOT_FOUND,
                        "闄勪欢涓嶅瓨鍦ㄦ垨鏃犳潈璁块棶: " + attachmentUuid));
    }

    /**
     * 灏?MIME 瀛楃涓茶В鏋愪负 Spring {@link MediaType}锛岃В鏋愬け璐ラ檷绾т负 application/octet-stream銆?
     */
    private MediaType resolveMediaType(String mime) {
        if (mime == null || mime.isBlank()) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
        try {
            return MediaType.parseMediaType(mime);
        } catch (Exception e) {
            log.warn("[ImageServe] MIME 瑙ｆ瀽澶辫触: {}, 闄嶇骇涓?octet-stream", mime);
            return MediaType.APPLICATION_OCTET_STREAM;
        }
    }
}

