package com.doublez.pocketmindserver.asset.api;

import com.doublez.pocketmindserver.asset.api.dto.AssetDTO;
import com.doublez.pocketmindserver.asset.application.AssetQueryService;
import com.doublez.pocketmindserver.asset.application.ImageServeService;
import com.doublez.pocketmindserver.asset.application.ImageUploadService;
import com.doublez.pocketmindserver.asset.api.dto.UploadResultDTO;
import com.doublez.pocketmindserver.shared.security.UserContext;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

/**
 * 鍥剧墖璧勪骇 REST Controller銆?
 *
 * <p>
 * 绔偣锛?
 * <ul>
 *   <li>{@code POST /api/assets/images} 鈥?涓婁紶鍥剧墖锛岃繑鍥炲惈瀹介珮鐨?UploadResultDTO</li>
 *   <li>{@code GET  /api/assets/images/{uuid}} 鈥?涓嬭浇/棰勮鍥剧墖锛岃嚜鍔ㄥ鐞?HTTP Range</li>
 * </ul>
 * </p>
 *
 * <p>
 * Range 澶勭悊绛栫暐锛堝湪 Controller 灞傚喅绛栵紝淇濇寔 Service 鑱岃矗鍗曚竴锛夛細
 * <ul>
 *   <li>鏈?{@code Range} 璇锋眰澶?鈫?杞彂缁?{@link ImageServeService#servePartialImage}锛岃繑鍥?206銆?/li>
 *   <li>鏃?{@code Range} 璇锋眰澶?鈫?杞彂缁?{@link ImageServeService#serveFullImage}锛岃繑鍥?200銆?/li>
 * </ul>
 * </p>
 */
@Slf4j
@RestController
@RequestMapping("/api/assets/images")
public class ImageAssetController {

    private final ImageUploadService uploadService;
    private final ImageServeService  serveService;
    private final AssetQueryService  assetQueryService;

    public ImageAssetController(ImageUploadService uploadService,
                                ImageServeService serveService,
                                AssetQueryService assetQueryService) {
        this.uploadService     = uploadService;
        this.serveService      = serveService;
        this.assetQueryService = assetQueryService;
    }

    /**
     * 涓婁紶鍥剧墖銆?
     *
     * <p>瑕佹眰 Content-Type: multipart/form-data锛屽瓧娈靛悕涓?{@code file}銆?
     * 涓婁紶鎴愬姛鍚庣珛鍗宠繑鍥炲楂樻暟鎹紝渚涘鎴风娓叉煋楠ㄦ灦灞忓崰浣嶏紝閬垮厤甯冨眬璺宠穬銆?/p>
     *
     * @param file 鍥剧墖鏂囦欢锛坢ultipart/form-data, field=file锛?
     * @return 鍖呭惈 uuid/mime/size/width/height 鐨勬爣鍑嗗搷搴?
     */
    @PostMapping(consumes = "multipart/form-data")
    public UploadResultDTO uploadImage(
            @RequestPart("file") MultipartFile file,
            @RequestParam(value = "noteUuid", required = false) UUID noteUuid,
            @RequestParam(value = "sortOrder", defaultValue = "0") int sortOrder) {

        long userId = parseUserId();
        log.info("[AssetController] 涓婁紶璇锋眰: userId={}, originalName={}, size={}B, noteUuid={}, sortOrder={}",
                userId, file.getOriginalFilename(), file.getSize(), noteUuid, sortOrder);

        UploadResultDTO result = uploadService.upload(file, userId, sortOrder);

        if (noteUuid != null) {
            assetQueryService.bindToNote(result.uuid(), userId, noteUuid);
            log.info("[AssetController] 涓婁紶鍚庣洿鎺ョ粦瀹? assetUuid={}, noteUuid={}", result.uuid(), noteUuid);
        }

        return result;
    }

    /**
     * 鑾峰彇鍥剧墖璧勬簮銆?
     *
     * <p>瀹㈡埛绔彲鎼哄甫 {@code Range} 璇锋眰澶村疄鐜版柇鐐圭画浼犳垨鍒嗗潡鍔犺浇
     * 锛堜緥濡傦細{@code Range: bytes=0-1048575}锛夈€?
     * 鏈?Range 鈫?206 Partial Content锛涙棤 Range 鈫?200 OK銆?/p>
     *
     * <p>娉ㄦ剰锛氳鎺ュ彛涓嶇粡杩?{@link com.doublez.pocketmind.common.web.ApiResponseAdvice}
     * 鐨勭粺涓€鍖呰锛屽洜涓哄搷搴?body 鏄簩杩涘埗璧勬簮娴侊紝涓嶉€傚悎 JSON 灏佽銆?/p>
     *
     * @param assetsUuid           璺緞涓殑闄勪欢 UUID
     * @param requestHeaders 鏉ヨ嚜璇锋眰鐨?HttpHeaders锛堝惈 Range 淇℃伅锛?
     * @return 200 鍏ㄩ噺 鎴?206 鍒嗘鍝嶅簲锛圧esponseEntity 缁曡繃缁熶竴鍖呰锛?
     */
    @GetMapping("/{assetsUuid}")
    public ResponseEntity<?> getImage(
            @PathVariable("assetsUuid") UUID assetsUuid,
            @RequestHeader HttpHeaders requestHeaders) {

        long userId = parseUserId();

        // 鍦?Controller 灞傚垽鏂?Range锛屼繚鎸?Service 鑱岃矗鍗曚竴
        if (!requestHeaders.getRange().isEmpty()) {
            return serveService.servePartialImage(assetsUuid, userId, requestHeaders);
        }

        return serveService.serveFullImage(assetsUuid, userId);
    }

    /**
     * 
     * @param noteUuid 绗旇 UUID
     * @return 璇ョ瑪璁颁笅鐨勬墍鏈夊浘鐗囪祫浜у厓鏁版嵁鍒楄〃
     */
    @GetMapping("/metadata/{noteUuid}")
    public List<AssetDTO> getImageMetadata(
            @PathVariable("noteUuid") UUID noteUuid) {

        long userId = parseUserId();
        return assetQueryService.listByNote(noteUuid,userId);
    }

    private long parseUserId() {
        return Long.parseLong(UserContext.getRequiredUserId());
    }
}

