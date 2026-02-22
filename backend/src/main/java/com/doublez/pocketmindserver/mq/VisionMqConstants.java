package com.doublez.pocketmindserver.mq;

/**
 * Vision 异步识别任务的 RabbitMQ 常量。
 */
public final class VisionMqConstants {

    private VisionMqConstants() {}

    // ---- 主队列 ----
    public static final String VISION_QUEUE        = "vision_queue";
    public static final String VISION_EXCHANGE     = "vision_exchange";
    public static final String VISION_ROUTING_KEY  = "vision.key";

    // ---- 死信队列 (DLQ) ----
    public static final String VISION_DLQ_QUEUE       = "vision_queue.dlq";
    public static final String VISION_DLQ_EXCHANGE    = "vision_dlq_exchange";
    public static final String VISION_DLQ_ROUTING_KEY = "vision.dlq";

    // ---- ContainerFactory Bean 名称 ----
    public static final String VISION_CONTAINER_FACTORY = "visionContainerFactory";
}
