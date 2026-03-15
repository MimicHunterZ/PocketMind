package com.doublez.pocketmindserver.asset.application;

import com.doublez.pocketmindserver.asset.api.dto.AssetExtractionDTO;
import com.doublez.pocketmindserver.asset.api.dto.AssetExtractionsResponse;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
@Slf4j
@RequiredArgsConstructor
public class AssetExtractionsService {
    private final AttachmentVisionRepository attachmentVisionRepository;

    public AssetExtractionsResponse getAssetsExtractions(long userId, UUID assetsUuid) {
        List<AssetExtractionDTO> all = attachmentVisionRepository
                .findByAttachmentUuid(userId, assetsUuid)
                .stream()
                .map(m -> new AssetExtractionDTO(
                        m.getAssetUuid(),
                        m.getContentType(),
                        m.getContent(),
                        m.getModel(),
                        m.getStatus() != null ? m.getStatus().name() : null))
                .toList();

        log.debug("[AssetExtraction] assetUuid={}, total={}",
                assetsUuid, all.size());

        return new AssetExtractionsResponse(all);
    }
}
