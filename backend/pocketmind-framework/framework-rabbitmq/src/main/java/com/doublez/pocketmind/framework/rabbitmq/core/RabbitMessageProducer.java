package com.doublez.pocketmind.framework.rabbitmq.core;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.AmqpException;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.amqp.rabbit.core.RabbitTemplate;

@Slf4j
@RequiredArgsConstructor
public class RabbitMessageProducer {

    private final RabbitTemplate rabbitTemplate;

    public void send(String exchange, String routingKey, Object message) {
        try {
            rabbitTemplate.convertAndSend(exchange, routingKey, message, msg -> {
                msg.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                return msg;
            });
        } catch (AmqpException ex) {
            log.error("[RabbitProducer] 消息发送失败 - exchange: {}, routingKey: {}", exchange, routingKey, ex);
            throw ex;
        }
    }

    public void sendWithDelay(String exchange, String routingKey, Object message, int delayMillis) {
        try {
            rabbitTemplate.convertAndSend(exchange, routingKey, message, msg -> {
                msg.getMessageProperties().setHeader("x-delay", delayMillis);
                msg.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                return msg;
            });
        } catch (AmqpException ex) {
            log.error(
                    "[RabbitProducer] 延迟消息发送失败 - exchange: {}, routingKey: {}, delayMillis: {}",
                    exchange,
                    routingKey,
                    delayMillis,
                    ex
            );
            throw ex;
        }
    }
}