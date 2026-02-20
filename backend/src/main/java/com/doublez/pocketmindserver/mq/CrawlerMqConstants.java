package com.doublez.pocketmindserver.mq;

public final class CrawlerMqConstants {

    private CrawlerMqConstants() {
    }

    public static final String CRAWLER_QUEUE = "crawler_queue";
    public static final String CRAWLER_EXCHANGE = "crawler_exchange";
    public static final String CRAWLER_ROUTING_KEY = "crawler.key";

    public static final String CRAWLER_DLQ_QUEUE = "crawler_queue.dlq";
    public static final String CRAWLER_DLQ_EXCHANGE = "crawler_dlq_exchange";
    public static final String CRAWLER_DLQ_ROUTING_KEY = "crawler.dlq";
}
