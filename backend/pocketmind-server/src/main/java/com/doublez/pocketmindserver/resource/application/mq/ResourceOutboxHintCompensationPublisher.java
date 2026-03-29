package com.doublez.pocketmindserver.resource.application.mq;

/**
 * Resource Outbox Hint 发布失败补偿发布器。
 */
public interface ResourceOutboxHintCompensationPublisher {

    /**
     * 将失败事件写入补偿通道。
     */
    void publishCompensation(ResourceOutboxHintEvent event, String reason);
}
