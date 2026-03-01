package com.doublez.pocketmind.framework.rabbitmq.config;

import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.JacksonJsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.amqp.rabbit.connection.CachingConnectionFactory;
import tools.jackson.databind.json.JsonMapper;

@AutoConfiguration
@ConditionalOnClass(RabbitTemplate.class)
public class PocketmindRabbitConfig {

    @Bean("pocketmindRabbitObjectMapper")
    @ConditionalOnMissingBean(name = "pocketmindRabbitObjectMapper")
    public JsonMapper pocketmindRabbitObjectMapper() {
        return JsonMapper.builder()
                .findAndAddModules()
            .build();
    }

    @Bean("pocketmindRabbitMessageConverter")
    @Primary
    @ConditionalOnMissingBean(name = "pocketmindRabbitMessageConverter")
    public MessageConverter pocketmindRabbitMessageConverter(JsonMapper pocketmindRabbitObjectMapper) {
        return new JacksonJsonMessageConverter(pocketmindRabbitObjectMapper);
    }

    @Bean("pocketmindRabbitTemplate")
    @Primary
    @ConditionalOnMissingBean(name = "pocketmindRabbitTemplate")
    public RabbitTemplate pocketmindRabbitTemplate(
            ConnectionFactory connectionFactory,
            @Qualifier("pocketmindRabbitMessageConverter") MessageConverter pocketmindRabbitMessageConverter,
            ObjectProvider<RabbitTemplate.ConfirmCallback> confirmCallbackProvider,
            ObjectProvider<RabbitTemplate.ReturnsCallback> returnsCallbackProvider
    ) {
        if (connectionFactory instanceof CachingConnectionFactory cachingConnectionFactory) {
            cachingConnectionFactory.setPublisherConfirmType(CachingConnectionFactory.ConfirmType.CORRELATED);
            cachingConnectionFactory.setPublisherReturns(true);
        }

        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(pocketmindRabbitMessageConverter);
        rabbitTemplate.setMandatory(true);
        confirmCallbackProvider.ifAvailable(rabbitTemplate::setConfirmCallback);
        returnsCallbackProvider.ifAvailable(rabbitTemplate::setReturnsCallback);
        return rabbitTemplate;
    }
}