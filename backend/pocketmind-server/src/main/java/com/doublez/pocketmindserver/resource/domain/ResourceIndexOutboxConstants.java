package com.doublez.pocketmindserver.resource.domain;

/**
 * Resource 索引 Outbox 常量。
 */
public final class ResourceIndexOutboxConstants {

    private ResourceIndexOutboxConstants() {
    }

    public static final String OPERATION_UPSERT = "UPSERT";
    public static final String OPERATION_DELETE = "DELETE";

    public static final String STATUS_PENDING = "PENDING";
    public static final String STATUS_PROCESSING = "PROCESSING";
    public static final String STATUS_COMPLETED = "COMPLETED";
}
