package com.doublez.pocketmindserver.resource.application.mq;

/**
 * Resource 索引 Outbox Hint 发布器。
 */
public interface ResourceOutboxHintPublisher {

    /**
     * 发送 outbox hint 消息。
     */
    void publish(ResourceOutboxHintEvent event);
}
