package com.doublez.pocketmindserver.asset.api;

import com.doublez.pocketmindserver.asset.application.ImageServeService;
import com.doublez.pocketmindserver.asset.application.ImageUploadService;
import com.doublez.pocketmindserver.asset.application.dto.UploadResultDTO;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmindserver.shared.web.ApiResponse;
import com.doublez.pocketmindserver.shared.web.TraceIdContext;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.ResourceRegion;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

/**
 * 图片资产 REST Controller。
 *
 * <p>
 * 端点：
 * <ul>
 *   <li>{@code POST /api/assets/images} — 上传图片，返回含宽高的 UploadResultDTO</li>
 *   <li>{@code GET  /api/assets/images/{uuid}} — 下载/预览图片，自动处理 HTTP Range</li>
 * </ul>
 * </p>
 *
 * <p>
 * Range 处理策略（在 Controller 层决策，保持 Service 职责单一）：
 * <ul>
 *   <li>有 {@code Range} 请求头 → 转发给 {@link ImageServeService#servePartialImage}，返回 206。</li>
 *   <li>无 {@code Range} 请求头 → 转发给 {@link ImageServeService#serveFullImage}，返回 200。</li>
 * </ul>
 * </p>
 */
@Slf4j
@RestController
@RequestMapping("/api/assets/images")
public class AssetController {

    private final ImageUploadService uploadService;
    private final ImageServeService  serveService;

    public AssetController(ImageUploadService uploadService, ImageServeService serveService) {
        this.uploadService = uploadService;
        this.serveService  = serveService;
    }

    /**
     * 上传图片。
     *
     * <p>要求 Content-Type: multipart/form-data，字段名为 {@code file}。
     * 上传成功后立即返回宽高数据，供客户端渲染骨架屏占位，避免布局跳跃。</p>
     *
     * @param file 图片文件（multipart/form-data, field=file）
     * @return 包含 uuid/mime/size/width/height 的标准响应
     */
    @PostMapping(consumes = "multipart/form-data")
    public ApiResponse<UploadResultDTO> uploadImage(
            @RequestPart("file") MultipartFile file) {

        long userId = parseUserId();
        log.info("[AssetController] 上传请求: userId={}, originalName={}, size={}B",
                userId, file.getOriginalFilename(), file.getSize());

        UploadResultDTO result = uploadService.upload(file, userId);
        return ApiResponse.ok(result, TraceIdContext.currentTraceId());
    }

    /**
     * 获取图片资源。
     *
     * <p>客户端可携带 {@code Range} 请求头实现断点续传或分块加载
     * （例如：{@code Range: bytes=0-1048575}）。
     * 有 Range → 206 Partial Content；无 Range → 200 OK。</p>
     *
     * <p>注意：该接口不经过 {@link com.doublez.pocketmindserver.shared.web.ApiResponseAdvice}
     * 的统一包装，因为响应 body 是二进制资源流，不适合 JSON 封装。</p>
     *
     * @param uuid           路径中的附件 UUID
     * @param requestHeaders 来自请求的 HttpHeaders（含 Range 信息）
     * @return 200 全量 或 206 分段响应（ResponseEntity 绕过统一包装）
     */
    @GetMapping("/{uuid}")
    public ResponseEntity<?> getImage(
            @PathVariable("uuid") UUID uuid,
            @RequestHeader HttpHeaders requestHeaders) {

        long userId = parseUserId();

        // 在 Controller 层判断 Range，保持 Service 职责单一
        if (!requestHeaders.getRange().isEmpty()) {
            ResponseEntity<ResourceRegion> partial = serveService.servePartialImage(uuid, userId, requestHeaders);
            return partial;
        }

        ResponseEntity<Resource> full = serveService.serveFullImage(uuid, userId);
        return full;
    }

    private long parseUserId() {
        return Long.parseLong(UserContext.getRequiredUserId());
    }
}
