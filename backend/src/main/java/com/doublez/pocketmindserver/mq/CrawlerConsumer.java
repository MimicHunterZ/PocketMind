package com.doublez.pocketmindserver.mq;

import com.doublez.pocketmindserver.mq.event.CrawlerRequestEvent;
import com.doublez.pocketmindserver.ai.application.NoteScrapeAndAnalyseService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class CrawlerConsumer {

    private final NoteScrapeAndAnalyseService noteScrapeAndAnalyseService;

    @RabbitListener(queues = CrawlerMqConstants.CRAWLER_QUEUE)
    public void handleCrawlerRequest(CrawlerRequestEvent event) {
        log.info("Processing crawler request for UUID: {}", event.uuid());
        noteScrapeAndAnalyseService.handle(event);
    }
}
