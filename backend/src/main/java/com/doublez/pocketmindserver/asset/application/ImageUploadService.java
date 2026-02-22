package com.doublez.pocketmindserver.asset.application;

import com.doublez.pocketmindserver.asset.application.dto.UploadResultDTO;
import com.doublez.pocketmindserver.asset.domain.NoteAttachment;
import com.doublez.pocketmindserver.asset.domain.NoteAttachmentRepository;
import com.doublez.pocketmindserver.asset.spi.AssetStore;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
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
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * 图片上传业务服务。
 *
 * <p><b>防雷清单（严格落实）：</b>
 * <ul>
 *   <li>临时文件缓冲：所有数据先落地磁盘临时文件，杜绝大图 OOM。</li>
 *   <li>防 OOM 宽高解析：通过 {@link ImageReader} 仅读取文件头元数据，
 *       绝对禁止 {@code ImageIO.read()} 把全图加载为 {@code BufferedImage}。</li>
 *   <li>try-finally 铁律：临时文件在 finally 块中强制删除，任何异常路径下均不泄漏。</li>
 * </ul>
 * </p>
 */
@Slf4j
@Service
public class ImageUploadService {

    // ---- 支持的图片格式白名单 ----
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp", "gif");
    private static final Set<String> ALLOWED_MIME_TYPES  = Set.of(
            "image/jpeg", "image/png", "image/webp", "image/gif"
    );
    // 扩展名 → 规范化扩展名映射（统一 .jpg）
    private static final Map<String, String> EXT_NORMALIZE = Map.of(
            "jpg",  "jpg",
            "jpeg", "jpg",
            "png",  "png",
            "webp", "webp",
            "gif",  "gif"
    );

    private static final DateTimeFormatter DATE_PATH_FMT = DateTimeFormatter.ofPattern("yyyy/MM/dd");

    private final AssetStore assetStore;
    private final NoteAttachmentRepository attachmentRepository;

    public ImageUploadService(AssetStore assetStore, NoteAttachmentRepository attachmentRepository) {
        this.assetStore = assetStore;
        this.attachmentRepository = attachmentRepository;
    }

    // 公共入口
    /**
     * 处理图片上传请求。
     *
     * @param file   客户端上传的 MultipartFile
     * @param userId 当前登录用户 ID（来自 UserContext）
     * @return 包含 uuid / width / height / size / mime 的 DTO
     */
    public UploadResultDTO upload(MultipartFile file, long userId) {
        // 1. 入参校验
        String originalName = file.getOriginalFilename();
        String ext          = extractAndValidateExtension(originalName);
        String mime         = resolveMime(file.getContentType(), ext);
        long   fileSize     = file.getSize();

        log.info("[ImageUpload] 接收文件: name={}, mime={}, size={}B, userId={}", originalName, mime, fileSize, userId);

        // 2. 将上传流吸收到操作系统临时目录，防止大文件 OOM
        File tempFile = null;
        try {
            tempFile = writeToTempFile(file.getInputStream(), ext);

            // 3. 高效解析宽高（仅读文件头，不加载完整像素数据）
            int[] dimensions = readImageDimensions(tempFile);
            int width  = dimensions[0];
            int height = dimensions[1];

            // 4. 生成业务 UUID 与 storageKey（YYYY/MM/DD/{uuid}.{normalizedExt}）
            UUID   attachmentUuid = UUID.randomUUID();
            String normalizedExt  = EXT_NORMALIZE.getOrDefault(ext.toLowerCase(), ext.toLowerCase());
            String storageKey     = buildStorageKey(attachmentUuid, normalizedExt);
            String userDir        = String.valueOf(userId);

            // 5. 物理落盘
            assetStore.saveFromFile(userDir, storageKey, tempFile, mime);

            // 6. 构建并持久化 NoteAttachment 实体
            NoteAttachment entity = buildEntity(attachmentUuid, userId, mime, fileSize,
                    originalName, storageKey, width, height);
            attachmentRepository.save(entity);

            log.info("[ImageUpload] 完成: uuid={}, storageKey={}, {}x{}", attachmentUuid, storageKey, width, height);

            // 7. 返回含宽高的 DTO，以供前端立即渲染骨架屏占位
            return new UploadResultDTO(attachmentUuid, mime, fileSize, width, height);

        } catch (IOException e) {
            log.error("[ImageUpload] IO 异常: {}", e.getMessage(), e);
            throw new BusinessException(ApiCode.ASSET_UPLOAD_FAILED, HttpStatus.INTERNAL_SERVER_ERROR, e.getMessage());
        } finally {
            // 铁律：无论成功或异常，都必须删除临时文件，杜绝磁盘泄漏
            deleteTempFileSilently(tempFile);
        }
    }

    // 私有工具方法
    /**
     * 校验文件扩展名并返回小写扩展名（不含点号）。
     */
    private String extractAndValidateExtension(String originalName) {
        if (originalName == null || !originalName.contains(".")) {
            throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST, "文件名缺少扩展名");
        }
        String ext = originalName.substring(originalName.lastIndexOf('.') + 1).toLowerCase();
        if (!ALLOWED_EXTENSIONS.contains(ext)) {
            throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST,
                    "不支持的扩展名: " + ext + "，仅允许 jpg/png/webp/gif");
        }
        return ext;
    }

    /**
     * 解析并校验 MIME 类型。
     * 优先使用请求头中的 Content-Type，如为空则根据扩展名推断。
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
     * 将 InputStream 写入操作系统临时目录中的临时文件。
     * <p>使用 {@code Files.createTempFile} 而非内存缓冲，避免大图 OOM。</p>
     */
    private File writeToTempFile(InputStream inputStream, String ext) throws IOException {
        File tempFile = Files.createTempFile("pocketmind-upload-", "." + ext).toFile();
        try (InputStream in = inputStream) {
            Files.copy(in, tempFile.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        }
        log.debug("[ImageUpload] 临时文件已写入: {}, size={}B", tempFile.getAbsolutePath(), tempFile.length());
        return tempFile;
    }

    /**
     * 高效提取图片宽高——<b>仅读取文件头元数据，绝对不加载全图像素数据。</b>
     *
     * <p>使用 {@link ImageIO#createImageInputStream(Object)} 打开流后，
     * 通过 {@link ImageReader#getWidth(int)} / {@link ImageReader#getHeight(int)}
     * 直接读取 EXIF/文件头中的尺寸信息。
     * 全过程禁止调用 {@code ImageIO.read()}/{@code reader.read()}，
     * 防止将数十 MB 的图片加载为 {@code BufferedImage} 导致 OOM。</p>
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
                // seekForwardOnly=true, ignoreMetadata=false（需要宽高元数据）
                reader.setInput(iis, true, false);
                int width  = reader.getWidth(0);
                int height = reader.getHeight(0);
                log.debug("[ImageUpload] 宽高解析成功: {}x{}", width, height);
                return new int[]{width, height};
            } finally {
                // 必须释放 reader，否则可能持有底层文件句柄
                reader.dispose();
            }
        }
    }

    /**
     * 生成 storageKey，格式：{YYYY/MM/DD}/{uuid}.{ext}
     * 子目录按日期分散，避免单目录文件过多。
     */
    private String buildStorageKey(UUID uuid, String ext) {
        String datePath = LocalDate.now().format(DATE_PATH_FMT);
        return datePath + "/" + uuid + "." + ext;
    }

    /**
     * 构建 NoteAttachment 实体，填充所有必须字段。
     */
    private NoteAttachment buildEntity(UUID uuid, long userId, String mime, long size,
                                       String originalFileName, String storageKey,
                                       int width, int height) {
        NoteAttachment e = new NoteAttachment();
        e.setUuid(uuid);
        e.setUserId(userId);
        e.setNoteUuid(null);             // 独立上传时先不关联笔记
        e.setType("image");
        e.setMime(mime);
        e.setSize(size);
        e.setOriginalFileName(originalFileName);
        e.setStorageKey(storageKey);
        e.setStorageType("local");
        e.setSha256(null);               // 暂不计算 sha256，按需开启
        e.setWidth(width);
        e.setHeight(height);
        e.setSource("user");
        e.setUpdatedAt(Instant.now().toEpochMilli());
        e.setIsDeleted(false);
        return e;
    }

    /**
     * 安全删除临时文件（not-throw）。在 finally 块中使用，保证不因删除失败而掩盖原始异常。
     */
    private void deleteTempFileSilently(File tempFile) {
        if (tempFile != null && tempFile.exists()) {
            boolean deleted = tempFile.delete();
            if (!deleted) {
                log.warn("[ImageUpload] 临时文件删除失败（将由 OS 清理）: {}", tempFile.getAbsolutePath());
            }
        }
    }
}
