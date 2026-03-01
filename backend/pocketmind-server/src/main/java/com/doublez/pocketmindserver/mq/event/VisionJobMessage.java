package com.doublez.pocketmindserver.mq.event;

import java.util.UUID;

/**
 * Vision 识别任务消息契约。
 *
 * <p>由 {@code ImageUploadService} 在图片落盘成功后投递；
 * 由 {@code VisionWorker} 监听并驱动 AI 识别管线。</p>
 *
 * @param attachmentUuid 附件业务 UUID（幂等键）
 * @param userId         所属用户 ID（用于存储路径隔离与归属校验）
 */
public record VisionJobMessage(
        UUID attachmentUuid,
        long userId
) {}
