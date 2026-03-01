package com.doublez.pocketmindserver.mq.event;

import java.util.UUID;

public record CrawlerRequestEvent(
        UUID uuid,
        String url,
        String userId,
        String userQuestion
) {}
