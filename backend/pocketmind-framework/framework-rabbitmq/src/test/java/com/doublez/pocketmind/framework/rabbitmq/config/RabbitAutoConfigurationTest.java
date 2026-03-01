package com.doublez.pocketmind.framework.rabbitmq.config;

import com.doublez.pocketmind.framework.rabbitmq.core.RabbitMessageProducer;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.support.converter.JacksonJsonMessageConverter;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class RabbitAutoConfigurationTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withUserConfiguration(TestConnectionFactoryConfig.class)
            .withConfiguration(AutoConfigurations.of(
                    PocketmindRabbitConfig.class,
                    RabbitProducerAutoConfiguration.class
            ));

    @Test
    void shouldAutoConfigureRabbitProducerAndJsonConverter() {
        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(RabbitMessageProducer.class);
            assertThat(context).hasBean("pocketmindRabbitTemplate");
            assertThat(context).hasBean("pocketmindRabbitMessageConverter");
            assertThat(context.getBean("pocketmindRabbitMessageConverter"))
                    .isInstanceOf(JacksonJsonMessageConverter.class);
        });
    }

    @Configuration(proxyBeanMethods = false)
    static class TestConnectionFactoryConfig {

        @Bean
        ConnectionFactory connectionFactory() {
            return mock(ConnectionFactory.class);
        }
    }
}
