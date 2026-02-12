package com.doublez.pocketmindserver.resource.infra.mq.config;

import com.doublez.pocketmindserver.resource.infra.mq.CrawlerMqConstants;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.JacksonJsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.listener.ConditionalRejectingErrorHandler;
import org.springframework.amqp.rabbit.retry.RepublishMessageRecoverer;
import org.springframework.amqp.rabbit.config.RetryInterceptorBuilder;
import org.springframework.context.annotation.Primary;

@Configuration
public class RabbitMQConfig {


    @Bean
    public Queue crawlerQueue() {
        return QueueBuilder.durable(CrawlerMqConstants.CRAWLER_QUEUE).build();
    }

    @Bean
    public DirectExchange crawlerExchange() {
        return new DirectExchange(CrawlerMqConstants.CRAWLER_EXCHANGE);
    }

    @Bean
    public Binding crawlerBinding(Queue crawlerQueue, DirectExchange crawlerExchange) {
        return BindingBuilder.bind(crawlerQueue).to(crawlerExchange).with(CrawlerMqConstants.CRAWLER_ROUTING_KEY);
    }

    @Bean
    public Queue crawlerDlqQueue() {
        return QueueBuilder.durable(CrawlerMqConstants.CRAWLER_DLQ_QUEUE).build();
    }

    @Bean
    public DirectExchange crawlerDlqExchange() {
        return new DirectExchange(CrawlerMqConstants.CRAWLER_DLQ_EXCHANGE);
    }

    @Bean
    public Binding crawlerDlqBinding(Queue crawlerDlqQueue, DirectExchange crawlerDlqExchange) {
        return BindingBuilder.bind(crawlerDlqQueue).to(crawlerDlqExchange).with(CrawlerMqConstants.CRAWLER_DLQ_ROUTING_KEY);
    }

    @Bean
    public MessageConverter messageConverter() {
        return new JacksonJsonMessageConverter();
    }

    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(messageConverter());
        return rabbitTemplate;
    }

    @Bean
    public RepublishMessageRecoverer crawlerRepublishRecoverer(RabbitTemplate rabbitTemplate) {
        return new RepublishMessageRecoverer(
                rabbitTemplate,
                CrawlerMqConstants.CRAWLER_DLQ_EXCHANGE,
                CrawlerMqConstants.CRAWLER_DLQ_ROUTING_KEY
        );
    }

    @Bean
    @Primary
    public SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(
            ConnectionFactory connectionFactory,
            MessageConverter messageConverter,
            RepublishMessageRecoverer crawlerRepublishRecoverer
    ) {
        SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setMessageConverter(messageConverter);
        factory.setDefaultRequeueRejected(false);
        factory.setErrorHandler(new ConditionalRejectingErrorHandler());
        factory.setAdviceChain(
                RetryInterceptorBuilder.stateless()
                        .maxRetries(3)
                        .recoverer(crawlerRepublishRecoverer)
                        .build()
        );
        return factory;
    }
}
