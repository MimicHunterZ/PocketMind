package com.doublez.pocketmindserver.mq.event;

import java.io.Serializable;
import java.util.UUID;

public record CrawlerRequestEvent(
        UUID uuid,
        String url,
        String userId,
        String userQuestion
) implements Serializable {}
