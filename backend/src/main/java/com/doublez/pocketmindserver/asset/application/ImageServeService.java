package com.doublez.pocketmindserver.asset.application;

import com.doublez.pocketmindserver.asset.domain.Asset;
import com.doublez.pocketmindserver.asset.domain.AssetRepository;
import com.doublez.pocketmindserver.asset.spi.AssetStore;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
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
 * 图片分发业务服务。
 *
 * <p>支持两种响应模式：
 * <ul>
 *   <li><b>HTTP 200</b>：无 Range 请求头，通过 Spring {@link Resource} 全量返回图片。</li>
 *   <li><b>HTTP 206</b>：有 Range 请求头，通过 {@link ResourceRegion} 返回指定字节段，
 *       完美支持断点续传/大图分块加载，同时为未来 S3 分段 GetObject 预留架构接口。</li>
 * </ul>
 * </p>
 *
 * <p><b>安全边界</b>：所有请求必须附带 userId，通过 DB 查询验证附件归属，杜绝越权访问。</p>
 */
@Slf4j
@Service
public class ImageServeService {

    /** 长缓存策略：私有缓存 1 年。图片内容不可变（UUID 唯一），安全使用长缓存。 */
    private static final CacheControl CACHE_CONTROL =
            CacheControl.maxAge(365, TimeUnit.DAYS).cachePrivate();

    private final AssetStore assetStore;
    private final AssetRepository AssetRepository;

    public ImageServeService(AssetStore assetStore, AssetRepository AssetRepository) {
        this.assetStore = assetStore;
        this.AssetRepository = AssetRepository;
    }

    /**
     * 返回完整图片资源（HTTP 200）。
     *
     * @param attachmentUuid 附件 UUID（来自 URL 路径）
     * @param userId         当前登录用户 ID（用于越权校验）
     * @return 包含 Content-Type 和 Cache-Control 头的 200 响应
     */
    public ResponseEntity<Resource> serveFullImage(UUID attachmentUuid, long userId) {
        Asset attachment = requireOwnedAsset(attachmentUuid, userId);
        Resource resource = assetStore.getResource(String.valueOf(userId), attachment.getStorageKey());

        log.debug("[ImageServe] 200 全量响应: uuid={}, key={}", attachmentUuid, attachment.getStorageKey());

        return ResponseEntity.ok()
                .contentType(resolveMediaType(attachment.getMime()))
                .cacheControl(CACHE_CONTROL)
                .body(resource);
    }

    /**
     * 返回图片的指定字节范围（HTTP 206），支持断点续传。
     *
     * <p>通过 Spring 原生 {@link ResourceRegion} + {@code ResourceRegionMessageConverter} 实现，
     * 底层自动处理字节写入，应用层零 Copy 开销。</p>
     *
     * @param attachmentUuid 附件 UUID
     * @param userId         当前登录用户 ID
     * @param requestHeaders 来自客户端的请求头（内含 Range 信息）
     * @return 206 Partial Content 响应
     */
    public ResponseEntity<ResourceRegion> servePartialImage(
            UUID attachmentUuid, long userId, HttpHeaders requestHeaders) {

        Asset attachment = requireOwnedAsset(attachmentUuid, userId);
        ResourceRegion region = assetStore.createResourceRegion(
                String.valueOf(userId), attachment.getStorageKey(), requestHeaders);

        log.debug("[ImageServe] 206 分段响应: uuid={}, position={}, count={}",
                attachmentUuid, region.getPosition(), region.getCount());

        return ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
                .contentType(resolveMediaType(attachment.getMime()))
                .cacheControl(CACHE_CONTROL)
                .body(region);
    }

    /**
     * 从 DB 查询附件并校验归属权（越权防御）。
     * 若附件不存在或不属于该用户，抛出 404 BusinessException。
     */
    private Asset requireOwnedAsset(UUID attachmentUuid, long userId) {
        return AssetRepository.findByUuidAndUserId(attachmentUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND,
                        HttpStatus.NOT_FOUND,
                        "附件不存在或无权访问: " + attachmentUuid));
    }

    /**
     * 将 MIME 字符串解析为 Spring {@link MediaType}，解析失败降级为 application/octet-stream。
     */
    private MediaType resolveMediaType(String mime) {
        if (mime == null || mime.isBlank()) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
        try {
            return MediaType.parseMediaType(mime);
        } catch (Exception e) {
            log.warn("[ImageServe] MIME 解析失败: {}, 降级为 octet-stream", mime);
            return MediaType.APPLICATION_OCTET_STREAM;
        }
    }
}
