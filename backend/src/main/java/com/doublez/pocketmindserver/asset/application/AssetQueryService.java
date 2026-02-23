package com.doublez.pocketmindserver.asset.application;

import com.doublez.pocketmindserver.asset.api.dto.AssetDTO;
import com.doublez.pocketmindserver.asset.domain.Asset;
import com.doublez.pocketmindserver.asset.domain.AssetRepository;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 资产查询与绑定服务。
 *
 * <p>主要功能：
 * <ul>
 *   <li>按笔记查询资产列表（含可访问的图片 URL）</li>
 *   <li>将孤立资产绑定到指定笔记（先上传后绑定场景）</li>
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
     * 查询指定笔记下的所有资产，并拼接可访问的下载 URL。
     *
     * @param noteUuid 笔记 UUID
     * @param userId   当前用户 ID（权限隔离）
     * @return 资产 DTO 列表
     */
    public List<AssetDTO> listByNote(UUID noteUuid, long userId) {
        List<Asset> assets = assetRepository.findByNoteUuidAndUserId(noteUuid, userId);
        return assets.stream()
                .map(this::toDto)
                .toList();
    }

    /**
     * 将指定资产绑定到笔记，同时校验所有权。
     *
     * @param assetUuid 资产 UUID
     * @param userId    当前用户 ID
     * @param noteUuid  目标笔记 UUID
     */
    public void bindToNote(UUID assetUuid, long userId, UUID noteUuid) {
        // 校验资产归属
        assetRepository.findByUuidAndUserId(assetUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND,
                        HttpStatus.NOT_FOUND,
                        "资产不存在或无权限: uuid=" + assetUuid));

        boolean updated = assetRepository.bindNoteUuid(assetUuid, userId, noteUuid);
        if (!updated) {
            throw new BusinessException(
                    ApiCode.ATTACHMENT_SAVE_FAILED,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "绑定失败: assetUuid=" + assetUuid);
        }
        log.info("[AssetQueryService] 资产绑定成功: assetUuid={}, noteUuid={}", assetUuid, noteUuid);
    }

    /** 将 Asset 实体转为 DTO，宽高从 metadata JSONB 中读取。 */
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
