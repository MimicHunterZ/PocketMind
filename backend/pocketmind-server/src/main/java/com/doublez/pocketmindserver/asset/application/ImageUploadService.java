package com.doublez.pocketmindserver.asset.application;

import com.doublez.pocketmindserver.asset.api.dto.UploadResultDTO;
import com.doublez.pocketmindserver.asset.domain.Asset;
import com.doublez.pocketmindserver.asset.domain.AssetRepository;
import com.doublez.pocketmindserver.asset.spi.AssetStore;
import com.doublez.pocketmindserver.mq.VisionMessagePublisher;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * 图片上传任务服务。
 *
 * <p><b>设计要点，务必注意：</b>
 * <ul>
 *   <li>使用临时文件缓存，避免将大量数据保存在内存导致 OOM。</li>
 *   <li>针对 OOM 做尺寸解析，优先通过 {@link ImageReader} 读取图片元数据，避免直接使用 {@code ImageIO.read()} 将大量图片读入为 {@code BufferedImage}。</li>
 *   <li>try-finally 约定：所有临时文件在 finally 中统一删除，避免临时文件泄露。</li>
 * </ul>
 * </p>
 */
@Slf4j
@Service
public class ImageUploadService {

    // ---- 支持的图片扩展名白名单 ----
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp", "gif");
    private static final Set<String> ALLOWED_MIME_TYPES  = Set.of(
            "image/jpeg", "image/png", "image/webp", "image/gif"
    );
    // 扩展名别名映射为统一后缀（内部以标准后缀存储）
    private static final Map<String, String> EXT_NORMALIZE = Map.of(
            "jpg",  "jpg",
            "jpeg", "jpg",
            "png",  "png",
            "webp", "webp",
            "gif",  "gif"
    );

    private static final DateTimeFormatter DATE_PATH_FMT = DateTimeFormatter.ofPattern("yyyy/MM/dd");

    private final AssetStore               assetStore;
    private final AssetRepository          attachmentRepository;
    private final VisionMessagePublisher   visionMessagePublisher;

    public ImageUploadService(AssetStore assetStore,
                              AssetRepository attachmentRepository,
                              VisionMessagePublisher visionMessagePublisher) {
        this.assetStore             = assetStore;
        this.attachmentRepository   = attachmentRepository;
        this.visionMessagePublisher = visionMessagePublisher;
    }

    // 入口方法
    /**
     * 处理图片上传请求。
     *
     * @param file   客户端上传的 MultipartFile
     * @param userId 当前登录用户 ID（可从 UserContext 获取）
     * @return 包含 uuid / width / height / size / mime 的 DTO
     */
    public UploadResultDTO upload(MultipartFile file, long userId, int sortOrder) {
        // 1. 入参校验
        String originalName = file.getOriginalFilename();
        String ext          = extractAndValidateExtension(originalName);
        String mime         = resolveMime(file.getContentType(), ext);
        long   fileSize     = file.getSize();

        log.info("[ImageUpload] 接收文件: name={}, mime={}, size={}B, userId={}", originalName, mime, fileSize, userId);

        // 2. 将上传内容写入临时文件以避免内存占用过大导致 OOM
        File tempFile = null;
        try {
            tempFile = writeToTempFile(file.getInputStream(), ext);

            // 3. 解析尺寸信息，尽量不加载整张图片到内存
            int[] dimensions = readImageDimensions(tempFile);
            int width  = dimensions[0];
            int height = dimensions[1];

            // 4. 生成资源 UUID 与 storageKey，格式：YYYY/MM/DD/{uuid}.{normalizedExt}
            UUID   attachmentUuid = UUID.randomUUID();
            String normalizedExt  = EXT_NORMALIZE.getOrDefault(ext.toLowerCase(), ext.toLowerCase());
            String storageKey     = buildStorageKey(attachmentUuid, normalizedExt);
            String userDir        = String.valueOf(userId);

            // 5. 物理落盘
            assetStore.saveFromFile(userDir, storageKey, tempFile, mime);

                // 6. 构建并持久化 Asset 实体
            Asset entity = buildEntity(attachmentUuid, userId, mime, fileSize,
                    originalName, storageKey, width, height, sortOrder);
            attachmentRepository.save(entity);

            log.info("[ImageUpload] 完成: uuid={}, storageKey={}, {}x{}", attachmentUuid, storageKey, width, height);

            // 7. 异步发送 Vision 分析任务，分析完成后可补充元信息到 DB
            visionMessagePublisher.publishVisionTask(attachmentUuid, userId);

            // 8. 返回最小化的结果 DTO，供前端展示已上传资源信息
            return new UploadResultDTO(attachmentUuid, mime, fileSize, width, height);

        } catch (IOException e) {
            log.error("[ImageUpload] IO 异常: {}", e.getMessage(), e);
            throw new BusinessException(ApiCode.ASSET_UPLOAD_FAILED, HttpStatus.INTERNAL_SERVER_ERROR, e.getMessage());
        } finally {
            // 注意：无论成功或失败，都应删除临时文件，避免磁盘残留垃圾
            deleteTempFileSilently(tempFile);
        }
    }

    // 私有工具方法
    /**
     * 检测文件扩展名并返回扩展名（不含点）。
     */
    private String extractAndValidateExtension(String originalName) {
        if (originalName == null || !originalName.contains(".")) {
            throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST, "文件名缺少扩展名");
        }
        String ext = originalName.substring(originalName.lastIndexOf('.') + 1).toLowerCase();
        if (!ALLOWED_EXTENSIONS.contains(ext)) {
            throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST,
                "不支持的扩展名: " + ext + "，仅支持 jpg/png/webp/gif");
        }
        return ext;
    }

    /**
     * 解析并校验 MIME 类型。
     * 优先使用请求头中的 Content-Type，若为空则根据扩展名推断。
     */
    private String resolveMime(String contentType, String ext) {
        String mime = (contentType != null && !contentType.isBlank())
                ? contentType.split(";")[0].trim().toLowerCase()
                : inferMimeFromExt(ext);
        if (!ALLOWED_MIME_TYPES.contains(mime)) {
            throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST,
                    "不支持的 MIME 类型: " + mime);
        }
        return mime;
    }

    private String inferMimeFromExt(String ext) {
        return switch (ext) {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png"         -> "image/png";
            case "webp"        -> "image/webp";
            case "gif"         -> "image/gif";
            default            -> "application/octet-stream";
        };
    }

    /**
     * 将 InputStream 写入操作系统临时目录下的临时文件。
     * 使用 {@code Files.createTempFile} 避免将数据缓存在 JVM 堆内存中导致 OOM。
     */
    private File writeToTempFile(InputStream inputStream, String ext) throws IOException {
        File tempFile = Files.createTempFile("pocketmind-upload-", "." + ext).toFile();
        try (InputStream in = inputStream) {
            Files.copy(in, tempFile.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        }
        log.debug("[ImageUpload] 临时文件创建成功: {}, size={}B", tempFile.getAbsolutePath(), tempFile.length());
        return tempFile;
    }

    /**
     * 解析并读取图片宽高，尽量避免将整张图片载入内存。
     * 使用 {@link ImageIO#createImageInputStream(Object)} 打开流，并通过
     * {@link ImageReader#getWidth(int)} / {@link ImageReader#getHeight(int)}
     * 直接读取像素尺寸（索引 0），以减少内存占用并支持大图片。
     *
     * @return int[]{width, height}
     */
    private int[] readImageDimensions(File tempFile) throws IOException {
        try (ImageInputStream iis = ImageIO.createImageInputStream(tempFile)) {
            if (iis == null) {
                throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST,
                        "无法创建 ImageInputStream，文件可能已损坏");
            }
            Iterator<ImageReader> readers = ImageIO.getImageReaders(iis);
            if (!readers.hasNext()) {
                throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST,
                        "无法识别图片格式，请检查文件完整性");
            }
            ImageReader reader = readers.next();
            try {
                // seekForwardOnly=true, ignoreMetadata=false锛堥渶瑕佸楂樺厓鏁版嵁锛?
                reader.setInput(iis, true, false);
                int width  = reader.getWidth(0);
                int height = reader.getHeight(0);
                log.debug("[ImageUpload] 宽高解析成功: {}x{}", width, height);
                return new int[]{width, height};
            } finally {
                // 蹇呴』閲婃斁 reader锛屽惁鍒欏彲鑳芥寔鏈夊簳灞傛枃浠跺彞鏌?
                reader.dispose();
            }
        }
    }

    /**
     * 生成 storageKey，格式：{YYYY/MM/DD}/{uuid}.{ext}
     * 以日期目录分散存储，避免单目录文件过多影响文件系统性能。
     */
    private String buildStorageKey(UUID uuid, String ext) {
        String datePath = LocalDate.now().format(DATE_PATH_FMT);
        return datePath + "/" + uuid + "." + ext;
    }

    /**
     * 构建 Asset 实体并填充基础字段。
     * 宽高等信息写入 `metadata`（JSONB），注意该字段仅用于展示/检索。
     */
    private Asset buildEntity(UUID uuid, long userId, String mime, long size,
                               String originalFileName, String storageKey,
                               int width, int height, int sortOrder) {
        Asset e = new Asset();
        e.setUuid(uuid);
        e.setUserId(userId);
        e.setNoteUuid(null);          // 鐙珛涓婁紶鏃跺厛涓嶅叧鑱旂瑪璁?
        e.setType("image");
        e.setSource("user");
        e.setMime(mime);
        e.setSize(size);
        e.setFileName(originalFileName);
        e.setStorageKey(storageKey);
        e.setStorageType("local");
        e.setSha256(null);            // 鏆備笉璁＄畻 sha256锛屾寜闇€寮€鍚?
        Map<String, Object> meta = new HashMap<>();
        meta.put("width", width);
        meta.put("height", height);
        e.setMetadata(meta);
        e.setBusinessMetadata(new HashMap<>());
        e.setSortOrder(sortOrder);
        e.setUpdatedAt(Instant.now().toEpochMilli());
        e.setIsDeleted(false);
        return e;
    }
    /**
     * 安全删除临时文件，失败时记录警告但不抛出异常（用于 finally 块）。
     */
    private void deleteTempFileSilently(File tempFile) {
        if (tempFile != null && tempFile.exists()) {
            boolean deleted = tempFile.delete();
            if (!deleted) {
                log.warn("[ImageUpload] 临时文件删除失败，交由 OS 处理: {}", tempFile.getAbsolutePath());
            }
        }
    }
}

