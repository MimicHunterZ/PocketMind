package com.doublez.pocketmindserver.mq;

import com.doublez.pocketmindserver.mq.event.CrawlerRequestEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CrawlerProducer {

    private final RabbitTemplate rabbitTemplate;

    public void sendCrawlerRequest(CrawlerRequestEvent event) {
        rabbitTemplate.convertAndSend(CrawlerMqConstants.CRAWLER_EXCHANGE, CrawlerMqConstants.CRAWLER_ROUTING_KEY, event);
    }
}
