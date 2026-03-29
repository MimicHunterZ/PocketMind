package com.doublez.pocketmindserver.mq;

/**
 * Resource Outbox Hint 的 MQ 常量。
 */
public final class ResourceOutboxMqConstants {

    private ResourceOutboxMqConstants() {
    }

    public static final String OUTBOX_HINT_QUEUE = "resource_outbox_hint_queue";
    public static final String OUTBOX_HINT_EXCHANGE = "resource_outbox_hint_exchange";
    public static final String OUTBOX_HINT_ROUTING_KEY = "resource.outbox.hint";

    public static final String OUTBOX_HINT_DLQ_QUEUE = "resource_outbox_hint_queue.dlq";
    public static final String OUTBOX_HINT_DLQ_EXCHANGE = "resource_outbox_hint_dlq_exchange";
    public static final String OUTBOX_HINT_DLQ_ROUTING_KEY = "resource.outbox.hint.dlq";

    public static final String OUTBOX_HINT_CONTAINER_FACTORY = "resourceOutboxHintContainerFactory";
    public static final String OUTBOX_HINT_DLQ_CONTAINER_FACTORY = "resourceOutboxHintDlqContainerFactory";
}
