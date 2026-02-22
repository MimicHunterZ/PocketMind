package com.doublez.pocketmindserver.mq.config;

import com.doublez.pocketmindserver.mq.CrawlerMqConstants;
import com.doublez.pocketmindserver.mq.VisionMqConstants;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.JacksonJsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.listener.ConditionalRejectingErrorHandler;
import org.springframework.amqp.rabbit.retry.RepublishMessageRecoverer;
import org.springframework.amqp.rabbit.config.RetryInterceptorBuilder;
import org.springframework.context.annotation.Primary;
import org.springframework.core.task.SimpleAsyncTaskExecutor;

@Configuration
public class RabbitMQConfig {

    // Crawler 队列
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

    // Vision 异步识别队列
    @Bean
    public Queue visionQueue() {
        return QueueBuilder.durable(VisionMqConstants.VISION_QUEUE).build();
    }

    @Bean
    public DirectExchange visionExchange() {
        return new DirectExchange(VisionMqConstants.VISION_EXCHANGE);
    }

    @Bean
    public Binding visionBinding(Queue visionQueue, DirectExchange visionExchange) {
        return BindingBuilder.bind(visionQueue).to(visionExchange).with(VisionMqConstants.VISION_ROUTING_KEY);
    }

    @Bean
    public Queue visionDlqQueue() {
        return QueueBuilder.durable(VisionMqConstants.VISION_DLQ_QUEUE).build();
    }

    @Bean
    public DirectExchange visionDlqExchange() {
        return new DirectExchange(VisionMqConstants.VISION_DLQ_EXCHANGE);
    }

    @Bean
    public Binding visionDlqBinding(Queue visionDlqQueue, DirectExchange visionDlqExchange) {
        return BindingBuilder.bind(visionDlqQueue).to(visionDlqExchange).with(VisionMqConstants.VISION_DLQ_ROUTING_KEY);
    }


    // 公共基础设施

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

    // Crawler Recoverer + ContainerFactory (@Primary)
    @Bean
    public RepublishMessageRecoverer crawlerRepublishRecoverer(RabbitTemplate rabbitTemplate) {
        return new RepublishMessageRecoverer(
                rabbitTemplate,
                CrawlerMqConstants.CRAWLER_DLQ_EXCHANGE,
                CrawlerMqConstants.CRAWLER_DLQ_ROUTING_KEY
        );
    }

    /**
     * 默认 ContainerFactory，供 CrawlerConsumer 使用（无需显式指定）。
     * 普通平台线程，3 次重试后转入 crawler DLQ。
     */
    @Bean
    @Primary
    public SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(
            ConnectionFactory connectionFactory,
            MessageConverter messageConverter,
            @Qualifier("crawlerRepublishRecoverer") RepublishMessageRecoverer crawlerRepublishRecoverer
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

    // Vision Recoverer + ContainerFactory
    @Bean
    public RepublishMessageRecoverer visionRepublishRecoverer(RabbitTemplate rabbitTemplate) {
        return new RepublishMessageRecoverer(
                rabbitTemplate,
                VisionMqConstants.VISION_DLQ_EXCHANGE,
                VisionMqConstants.VISION_DLQ_ROUTING_KEY
        );
    }

    /**
     * Vision 专属 ContainerFactory。
     * <p>
     * 关键配置：通过 {@link SimpleAsyncTaskExecutor#setVirtualThreads(true)} 开启 JDK 21
     * 虚拟线程，实现并发 AI 调用的高吞吐（每个消息都在独立虚拟线程中执行，无平台线程阻塞）。
     * 3 次重试后由 {@code visionRepublishRecoverer} 将消息路由到 DLQ，确保不无限重试。
     * </p>
     */
    @Bean(VisionMqConstants.VISION_CONTAINER_FACTORY)
    public SimpleRabbitListenerContainerFactory visionContainerFactory(
            ConnectionFactory connectionFactory,
            MessageConverter messageConverter,
            @Qualifier("visionRepublishRecoverer") RepublishMessageRecoverer visionRepublishRecoverer
    ) {
        // 虚拟线程执行器：每个消息独占一个轻量级虚拟线程
        SimpleAsyncTaskExecutor virtualExecutor = new SimpleAsyncTaskExecutor("vision-worker-");
        virtualExecutor.setVirtualThreads(true);

        SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
        factory.setConnectionFactory(connectionFactory);
        factory.setMessageConverter(messageConverter);
        factory.setTaskExecutor(virtualExecutor);
        factory.setDefaultRequeueRejected(false);
        factory.setErrorHandler(new ConditionalRejectingErrorHandler());
        factory.setAdviceChain(
                RetryInterceptorBuilder.stateless()
                        .maxRetries(3)
                        .recoverer(visionRepublishRecoverer)
                        .build()
        );
        return factory;
    }
}
