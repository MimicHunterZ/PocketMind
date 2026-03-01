package com.doublez.pocketmindserver.mq;

import com.doublez.pocketmind.framework.rabbitmq.core.RabbitMessageProducer;
import com.doublez.pocketmindserver.mq.event.CrawlerRequestEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CrawlerProducer {

    private final RabbitMessageProducer rabbitMessageProducer;

    public void sendCrawlerRequest(CrawlerRequestEvent event) {
        rabbitMessageProducer.send(CrawlerMqConstants.CRAWLER_EXCHANGE, CrawlerMqConstants.CRAWLER_ROUTING_KEY, event);
    }
}
