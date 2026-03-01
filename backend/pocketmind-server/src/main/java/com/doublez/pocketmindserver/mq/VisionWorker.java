package com.doublez.pocketmindserver.mq;

import com.doublez.pocketmindserver.ai.application.VisionService;
import com.doublez.pocketmindserver.asset.domain.Asset;
import com.doublez.pocketmindserver.asset.domain.AssetRepository;
import com.doublez.pocketmindserver.asset.spi.AssetStore;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionEntity;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionRepository;
import com.doublez.pocketmindserver.attachment.domain.vision.VisionStatus;
import com.doublez.pocketmindserver.mq.event.VisionJobMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import org.springframework.util.MimeType;
import org.springframework.util.MimeTypeUtils;

import java.util.List;
import java.util.UUID;

/**
 * Vision 异步识别消费者。
 *
 * <p><b>幂等铁律</b>：每次投递前先查 DB，若已 DONE 直接 Ack；若 PENDING/FAILED
 * 则复用已有实体，绝不重复写行。</p>
 *
 * <p><b>容错策略</b>：整条管线（含资源获取 + AI 调用）被统一 try-catch 包裹，
 * 任何异常均先将实体标记 FAILED 落库，再 re-throw 触发 Spring Retry（3 次）。
 * 重试耗尽后由 RepublishMessageRecoverer 将消息路由到 {@code vision_queue.dlq}。</p>
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class VisionWorker {

    // todo
    private static final String MODEL_LABEL = "vision-analyze";

    private final AttachmentVisionRepository attachmentVisionRepository;
    private final AssetRepository            assetRepository;
    private final AssetStore                 assetStore;
    private final VisionService              visionService;

    @RabbitListener(
            queues           = VisionMqConstants.VISION_QUEUE,
            containerFactory = VisionMqConstants.VISION_CONTAINER_FACTORY
    )
    public void handleVisionJob(VisionJobMessage message) {
        UUID attachmentUuid = message.attachmentUuid();
        long userId         = message.userId();

        log.info("[VisionWorker] 收到识别任务 - attachmentUuid: {}, userId: {}", attachmentUuid, userId);

        // ── 1. 幂等防御 ───────────────────────────────────────────────────────
        List<AttachmentVisionEntity> existing =
                attachmentVisionRepository.findByAttachmentUuid(userId, attachmentUuid);

        if (existing.stream().anyMatch(e -> VisionStatus.DONE.equals(e.getStatus()))) {
            log.warn("[VisionWorker] 幂等跳过（已存在 DONE 记录）- assetUuid: {}", attachmentUuid);
            return;
        }

        // ── 2. 新建或复用 Vision 实体（在 AI 调用之前落库，确保有记录可以 markFailed）
        // 若存在 PENDING/FAILED 则直接复用，避免每次重试都重复 INSERT
        AttachmentVisionEntity visionEntity;
        if (existing.isEmpty()) {
            visionEntity = AttachmentVisionEntity.create(UUID.randomUUID(), userId, attachmentUuid, MODEL_LABEL);
            try {
                attachmentVisionRepository.save(visionEntity);
                log.debug("[VisionWorker] 创建 PENDING 实体 - uuid: {}", visionEntity.getUuid());
            } catch (Exception saveEx) {
                log.error("[VisionWorker] 创建 PENDING 记录失败，将触发重试 - attachmentUuid: {}, userId: {}, error: {}",
                        attachmentUuid, userId, saveEx.getMessage(), saveEx);
                throw new RuntimeException(
                        "无法创建 Vision PENDING 记录: attachmentUuid=" + attachmentUuid,
                        saveEx
                );
            }
        } else {
            visionEntity = existing.getFirst();
            log.debug("[VisionWorker] 复用已有实体 - uuid: {}, status: {}", visionEntity.getUuid(), visionEntity.getStatus());
        }

        // ── 3. 加载资产元数据（查不到直接抛，不需要 markFailed） ─────────────
        Asset asset = assetRepository
                .findByUuidAndUserId(attachmentUuid, userId)
                .orElseThrow(() -> new IllegalStateException(
                        "资产记录不存在: assetUuid=" + attachmentUuid + ", userId=" + userId));

        // ── 4. 获取存储资源 + AI 调用（统一 try-catch，任何异常都 markFailed）─
        try {
            Resource imageResource = assetStore.getResource(
                    String.valueOf(userId),
                    asset.getStorageKey()
            );

            MimeType mimeType;
            try {
                mimeType = MimeTypeUtils.parseMimeType(asset.getMime());
            } catch (Exception e) {
                log.warn("[VisionWorker] MIME 解析失败（{}），降级为 image/jpeg - assetUuid: {}",
                        asset.getMime(), attachmentUuid);
                mimeType = MimeTypeUtils.IMAGE_JPEG;
            }

            String visionText = visionService.analyzeImage(imageResource, mimeType);

            visionEntity.markDone(visionText);
            attachmentVisionRepository.update(visionEntity);
            log.info("[VisionWorker] 识别成功 - assetUuid: {}, textLen: {}",
                    attachmentUuid, visionText.length());

        } catch (Exception e) {
            // 每次重试失败都 markFailed 并更新 DB，确保状态可被监控；
            // 重新抛出让 Spring Retry → RepublishMessageRecoverer 处理。
            log.error("[VisionWorker] 管线异常，将触发重试 - assetUuid: {}, entityUuid: {}, error: {}",
                    attachmentUuid, visionEntity.getUuid(), e.getMessage(), e);
            try {
                visionEntity.markFailed();
                attachmentVisionRepository.update(visionEntity);
            } catch (Exception updateEx) {
                log.error("[VisionWorker] markFailed 落库也失败 - entityUuid: {}, cause: {}",
                        visionEntity.getUuid(), updateEx.getMessage(), updateEx);
            }
            throw new RuntimeException("Vision 管线失败: assetUuid=" + attachmentUuid, e);
        }
    }
}
