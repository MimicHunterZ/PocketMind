package com.doublez.pocketmind.framework.rabbitmq.config;

import com.doublez.pocketmind.framework.rabbitmq.core.RabbitMessageProducer;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;

@AutoConfiguration(after = PocketmindRabbitConfig.class)
@ConditionalOnClass(RabbitTemplate.class)
public class RabbitProducerAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public RabbitMessageProducer rabbitMessageProducer(
            @Qualifier("pocketmindRabbitTemplate") RabbitTemplate pocketmindRabbitTemplate
    ) {
        return new RabbitMessageProducer(pocketmindRabbitTemplate);
    }
}