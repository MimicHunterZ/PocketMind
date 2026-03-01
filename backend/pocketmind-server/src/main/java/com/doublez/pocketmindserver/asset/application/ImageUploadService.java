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
 * 鍥剧墖涓婁紶涓氬姟鏈嶅姟銆?
 *
 * <p><b>闃查浄娓呭崟锛堜弗鏍艰惤瀹烇級锛?/b>
 * <ul>
 *   <li>涓存椂鏂囦欢缂撳啿锛氭墍鏈夋暟鎹厛钀藉湴纾佺洏涓存椂鏂囦欢锛屾潨缁濆ぇ鍥?OOM銆?/li>
 *   <li>闃?OOM 瀹介珮瑙ｆ瀽锛氶€氳繃 {@link ImageReader} 浠呰鍙栨枃浠跺ご鍏冩暟鎹紝
 *       缁濆绂佹 {@code ImageIO.read()} 鎶婂叏鍥惧姞杞戒负 {@code BufferedImage}銆?/li>
 *   <li>try-finally 閾佸緥锛氫复鏃舵枃浠跺湪 finally 鍧椾腑寮哄埗鍒犻櫎锛屼换浣曞紓甯歌矾寰勪笅鍧囦笉娉勬紡銆?/li>
 * </ul>
 * </p>
 */
@Slf4j
@Service
public class ImageUploadService {

    // ---- 鏀寔鐨勫浘鐗囨牸寮忕櫧鍚嶅崟 ----
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp", "gif");
    private static final Set<String> ALLOWED_MIME_TYPES  = Set.of(
            "image/jpeg", "image/png", "image/webp", "image/gif"
    );
    // 鎵╁睍鍚?鈫?瑙勮寖鍖栨墿灞曞悕鏄犲皠锛堢粺涓€ .jpg锛?
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

    // 鍏叡鍏ュ彛
    /**
     * 澶勭悊鍥剧墖涓婁紶璇锋眰銆?
     *
     * @param file   瀹㈡埛绔笂浼犵殑 MultipartFile
     * @param userId 褰撳墠鐧诲綍鐢ㄦ埛 ID锛堟潵鑷?UserContext锛?
     * @return 鍖呭惈 uuid / width / height / size / mime 鐨?DTO
     */
    public UploadResultDTO upload(MultipartFile file, long userId, int sortOrder) {
        // 1. 鍏ュ弬鏍￠獙
        String originalName = file.getOriginalFilename();
        String ext          = extractAndValidateExtension(originalName);
        String mime         = resolveMime(file.getContentType(), ext);
        long   fileSize     = file.getSize();

        log.info("[ImageUpload] 鎺ユ敹鏂囦欢: name={}, mime={}, size={}B, userId={}", originalName, mime, fileSize, userId);

        // 2. 灏嗕笂浼犳祦鍚告敹鍒版搷浣滅郴缁熶复鏃剁洰褰曪紝闃叉澶ф枃浠?OOM
        File tempFile = null;
        try {
            tempFile = writeToTempFile(file.getInputStream(), ext);

            // 3. 楂樻晥瑙ｆ瀽瀹介珮锛堜粎璇绘枃浠跺ご锛屼笉鍔犺浇瀹屾暣鍍忕礌鏁版嵁锛?
            int[] dimensions = readImageDimensions(tempFile);
            int width  = dimensions[0];
            int height = dimensions[1];

            // 4. 鐢熸垚涓氬姟 UUID 涓?storageKey锛圷YYY/MM/DD/{uuid}.{normalizedExt}锛?
            UUID   attachmentUuid = UUID.randomUUID();
            String normalizedExt  = EXT_NORMALIZE.getOrDefault(ext.toLowerCase(), ext.toLowerCase());
            String storageKey     = buildStorageKey(attachmentUuid, normalizedExt);
            String userDir        = String.valueOf(userId);

            // 5. 鐗╃悊钀界洏
            assetStore.saveFromFile(userDir, storageKey, tempFile, mime);

            // 6. 鏋勫缓骞舵寔涔呭寲 Asset 瀹炰綋
            Asset entity = buildEntity(attachmentUuid, userId, mime, fileSize,
                    originalName, storageKey, width, height, sortOrder);
            attachmentRepository.save(entity);

            log.info("[ImageUpload] 瀹屾垚: uuid={}, storageKey={}, {}x{}", attachmentUuid, storageKey, width, height);

            // 7. 寮傛鎶曢€?Vision 璇嗗埆浠诲姟锛堝浘鐗囪惤鐩?+ DB 钀藉簱鍧囧畬鎴愬悗鎵嶆姇閫掞紝淇濋殰骞傜瓑鍙噸璇曪級
            visionMessagePublisher.publishVisionTask(attachmentUuid, userId);

            // 8. 杩斿洖鍚楂樼殑 DTO锛屼互渚涘墠绔珛鍗虫覆鏌撻鏋跺睆鍗犱綅
            return new UploadResultDTO(attachmentUuid, mime, fileSize, width, height);

        } catch (IOException e) {
            log.error("[ImageUpload] IO 寮傚父: {}", e.getMessage(), e);
            throw new BusinessException(ApiCode.ASSET_UPLOAD_FAILED, HttpStatus.INTERNAL_SERVER_ERROR, e.getMessage());
        } finally {
            // 閾佸緥锛氭棤璁烘垚鍔熸垨寮傚父锛岄兘蹇呴』鍒犻櫎涓存椂鏂囦欢锛屾潨缁濈鐩樻硠婕?
            deleteTempFileSilently(tempFile);
        }
    }

    // 绉佹湁宸ュ叿鏂规硶
    /**
     * 鏍￠獙鏂囦欢鎵╁睍鍚嶅苟杩斿洖灏忓啓鎵╁睍鍚嶏紙涓嶅惈鐐瑰彿锛夈€?
     */
    private String extractAndValidateExtension(String originalName) {
        if (originalName == null || !originalName.contains(".")) {
            throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST, "鏂囦欢鍚嶇己灏戞墿灞曞悕");
        }
        String ext = originalName.substring(originalName.lastIndexOf('.') + 1).toLowerCase();
        if (!ALLOWED_EXTENSIONS.contains(ext)) {
            throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST,
                    "涓嶆敮鎸佺殑鎵╁睍鍚? " + ext + "锛屼粎鍏佽 jpg/png/webp/gif");
        }
        return ext;
    }

    /**
     * 瑙ｆ瀽骞舵牎楠?MIME 绫诲瀷銆?
     * 浼樺厛浣跨敤璇锋眰澶翠腑鐨?Content-Type锛屽涓虹┖鍒欐牴鎹墿灞曞悕鎺ㄦ柇銆?
     */
    private String resolveMime(String contentType, String ext) {
        String mime = (contentType != null && !contentType.isBlank())
                ? contentType.split(";")[0].trim().toLowerCase()
                : inferMimeFromExt(ext);
        if (!ALLOWED_MIME_TYPES.contains(mime)) {
            throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST,
                    "涓嶆敮鎸佺殑 MIME 绫诲瀷: " + mime);
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
     * 灏?InputStream 鍐欏叆鎿嶄綔绯荤粺涓存椂鐩綍涓殑涓存椂鏂囦欢銆?
     * <p>浣跨敤 {@code Files.createTempFile} 鑰岄潪鍐呭瓨缂撳啿锛岄伩鍏嶅ぇ鍥?OOM銆?/p>
     */
    private File writeToTempFile(InputStream inputStream, String ext) throws IOException {
        File tempFile = Files.createTempFile("pocketmind-upload-", "." + ext).toFile();
        try (InputStream in = inputStream) {
            Files.copy(in, tempFile.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        }
        log.debug("[ImageUpload] 涓存椂鏂囦欢宸插啓鍏? {}, size={}B", tempFile.getAbsolutePath(), tempFile.length());
        return tempFile;
    }

    /**
     * 楂樻晥鎻愬彇鍥剧墖瀹介珮鈥斺€?b>浠呰鍙栨枃浠跺ご鍏冩暟鎹紝缁濆涓嶅姞杞藉叏鍥惧儚绱犳暟鎹€?/b>
     *
     * <p>浣跨敤 {@link ImageIO#createImageInputStream(Object)} 鎵撳紑娴佸悗锛?
     * 閫氳繃 {@link ImageReader#getWidth(int)} / {@link ImageReader#getHeight(int)}
     * 鐩存帴璇诲彇 EXIF/鏂囦欢澶翠腑鐨勫昂瀵镐俊鎭€?
     * 鍏ㄨ繃绋嬬姝㈣皟鐢?{@code ImageIO.read()}/{@code reader.read()}锛?
     * 闃叉灏嗘暟鍗?MB 鐨勫浘鐗囧姞杞戒负 {@code BufferedImage} 瀵艰嚧 OOM銆?/p>
     *
     * @return int[]{width, height}
     */
    private int[] readImageDimensions(File tempFile) throws IOException {
        try (ImageInputStream iis = ImageIO.createImageInputStream(tempFile)) {
            if (iis == null) {
                throw new BusinessException(ApiCode.ASSET_INVALID_FORMAT, HttpStatus.BAD_REQUEST,
                        "鏃犳硶鍒涘缓 ImageInputStream锛屾枃浠跺彲鑳藉凡鎹熷潖");
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
                log.debug("[ImageUpload] 瀹介珮瑙ｆ瀽鎴愬姛: {}x{}", width, height);
                return new int[]{width, height};
            } finally {
                // 蹇呴』閲婃斁 reader锛屽惁鍒欏彲鑳芥寔鏈夊簳灞傛枃浠跺彞鏌?
                reader.dispose();
            }
        }
    }

    /**
     * 鐢熸垚 storageKey锛屾牸寮忥細{YYYY/MM/DD}/{uuid}.{ext}
     * 瀛愮洰褰曟寜鏃ユ湡鍒嗘暎锛岄伩鍏嶅崟鐩綍鏂囦欢杩囧銆?
     */
    private String buildStorageKey(UUID uuid, String ext) {
        String datePath = LocalDate.now().format(DATE_PATH_FMT);
        return datePath + "/" + uuid + "." + ext;
    }

    /**
     * 鏋勫缓 Asset 瀹炰綋锛屽～鍏呮墍鏈夊繀椤诲瓧娈点€?
     * 瀹介珮鍐欏叆 metadata JSONB锛屼笉浣滀负鐙珛鍒楀瓨鍌ㄣ€?
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
     * 瀹夊叏鍒犻櫎涓存椂鏂囦欢锛坣ot-throw锛夈€傚湪 finally 鍧椾腑浣跨敤锛屼繚璇佷笉鍥犲垹闄ゅけ璐ヨ€屾帺鐩栧師濮嬪紓甯搞€?
     */
    private void deleteTempFileSilently(File tempFile) {
        if (tempFile != null && tempFile.exists()) {
            boolean deleted = tempFile.delete();
            if (!deleted) {
                log.warn("[ImageUpload] 涓存椂鏂囦欢鍒犻櫎澶辫触锛堝皢鐢?OS 娓呯悊锛? {}", tempFile.getAbsolutePath());
            }
        }
    }
}

