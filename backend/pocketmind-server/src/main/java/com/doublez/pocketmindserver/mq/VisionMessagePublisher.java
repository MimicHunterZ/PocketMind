package com.doublez.pocketmindserver.mq;

import com.doublez.pocketmindserver.mq.event.VisionJobMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * Vision 识别任务投递器。
 *
 * <p>由 {@code ImageUploadService} 在图片落盘成功后调用，
 * 将识别任务异步送入 {@code vision_queue}，由 {@code VisionWorker} 消费。</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class VisionMessagePublisher {

    private final RabbitTemplate rabbitTemplate;

    /**
     * 投递图片识别任务。
     *
     * @param attachmentUuid 已落盘的附件 UUID（幂等键）
     * @param userId         所属用户 ID（用于存储路径隔离）
     */
    public void publishVisionTask(UUID attachmentUuid, long userId) {
        VisionJobMessage message = new VisionJobMessage(attachmentUuid, userId);
        rabbitTemplate.convertAndSend(
                VisionMqConstants.VISION_EXCHANGE,
                VisionMqConstants.VISION_ROUTING_KEY,
                message
        );
        log.info("[VisionMQ] 任务已投递 - attachmentUuid: {}, userId: {}", attachmentUuid, userId);
    }
}
