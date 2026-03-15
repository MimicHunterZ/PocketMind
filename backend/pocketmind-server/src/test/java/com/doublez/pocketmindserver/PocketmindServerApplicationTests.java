package com.doublez.pocketmindserver;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.context.annotation.Bean;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.amqp.rabbit.connection.Connection;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;

import com.doublez.pocketmindserver.auth.infra.persistence.UserAccountRepository;
import com.doublez.pocketmindserver.note.infra.persistence.note.NoteMapper;
import com.doublez.pocketmindserver.note.infra.persistence.category.CategoryMapper;
import com.doublez.pocketmindserver.note.infra.persistence.tag.TagMapper;
import com.doublez.pocketmindserver.note.infra.persistence.note.NoteTagRelationMapper;
import com.doublez.pocketmindserver.attachment.infra.persistence.attachment.AttachmentMapper;
import com.doublez.pocketmindserver.attachment.infra.persistence.vision.AttachmentVisionMapper;
import com.doublez.pocketmindserver.chat.infra.persistence.session.ChatSessionMapper;
import com.doublez.pocketmindserver.chat.infra.persistence.message.ChatMessageMapper;
import com.doublez.pocketmindserver.sync.infra.persistence.SyncChangeLogMapper;

@SpringBootTest(properties = {
    // 避免 application.yml 默认激活 dev。
    "spring.profiles.active=test",

    // 测试只验证 Spring 容器能启动：避免依赖外部基础设施。
    "spring.autoconfigure.exclude=" +
        // Spring Boot 4 迁移后的新包名（org.springframework.boot.jdbc.autoconfigure.*）。
        "org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration," +
        "org.springframework.boot.jdbc.autoconfigure.DataSourceInitializationAutoConfiguration," +
        "org.springframework.boot.jdbc.autoconfigure.DataSourceTransactionManagerAutoConfiguration," +
        "org.springframework.boot.jdbc.autoconfigure.JdbcClientAutoConfiguration," +
        "org.springframework.boot.jdbc.autoconfigure.JdbcTemplateAutoConfiguration," +
        "org.springframework.boot.jdbc.autoconfigure.JndiDataSourceAutoConfiguration," +
        "org.springframework.boot.jdbc.autoconfigure.sql.init.SqlInitializationAutoConfiguration," +

        // 兼容旧包名（org.springframework.boot.autoconfigure.jdbc.*）。
        "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration," +
        "org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration," +
        "org.springframework.boot.autoconfigure.jdbc.JdbcClientAutoConfiguration," +
        "org.springframework.boot.autoconfigure.jdbc.JdbcTemplateAutoConfiguration," +
        "org.springframework.boot.autoconfigure.jdbc.JndiDataSourceAutoConfiguration," +
        "org.springframework.boot.autoconfigure.sql.init.SqlInitializationAutoConfiguration," +
        "org.springframework.boot.autoconfigure.data.redis.RedisAutoConfiguration," +
        "org.springframework.boot.autoconfigure.data.redis.RedisRepositoriesAutoConfiguration," +
        "org.springframework.boot.autoconfigure.amqp.RabbitAutoConfiguration," +
        // Spring Boot 4 迁移后的 AMQP 自动配置包名。
        "org.springframework.boot.amqp.autoconfigure.RabbitAutoConfiguration",

    // 双保险：禁止 Rabbit listener 自动启动（避免本机没有 RabbitMQ 时 contextLoads 失败）。
    "spring.rabbitmq.listener.simple.auto-startup=false",
    "spring.rabbitmq.listener.direct.auto-startup=false",

    // 双保险：禁止 SQL 初始化。
    "spring.sql.init.mode=never",

    // 多厂商路由（业务侧）：提供 dummy 值让 contextLoads 能启动。
    "pocketmind.ai.providers.routes.chat-primary=deepseek",
    "pocketmind.ai.providers.routes.chat-secondary=deepseek",
    "pocketmind.ai.providers.routes.chat-fallback=deepseek",
    "pocketmind.ai.providers.routes.vision-primary=dashscope",

    // EmailServiceImpl 依赖：避免缺少 spring.mail.username 导致容器启动失败。
    "spring.mail.username=dummy@pocketmind.local",

    // JwtTokenService 依赖：避免因缺少 JWT 配置导致容器启动失败。
    "pocketmind.jwt.secret=dummy-secret",
    "pocketmind.jwt.user-id-claim=userId",
    "pocketmind.jwt.leeway-seconds=5",
    "pocketmind.jwt.token-ttl-seconds=3600",

    // JinaReaderClient 依赖：避免缺少占位符导致容器启动失败。
    "spring.ai.alibaba.toolcalling.jinacrawler.api-key=jina_xxx",

    "pocketmind.ai.providers.configs.deepseek.api-key=dummy",
    "pocketmind.ai.providers.configs.deepseek.base-url=https://api.deepseek.com",
    "pocketmind.ai.providers.configs.deepseek.model=deepseek-chat",

    "pocketmind.ai.providers.configs.dashscope.api-key=dummy",
    "pocketmind.ai.providers.configs.dashscope.base-url=https://dashscope.aliyuncs.com/compatible-mode",
    "pocketmind.ai.providers.configs.dashscope.model=qwen3.5-plus"
})
class PocketmindServerApplicationTests {

    // Mock 所有 MyBatis Mapper 接口，避免 DataSource 不可用时容器启动失败
    @MockitoBean NoteMapper noteMapper;
    @MockitoBean CategoryMapper categoryMapper;
    @MockitoBean TagMapper tagMapper;
    @MockitoBean NoteTagRelationMapper noteTagRelationMapper;
    @MockitoBean AttachmentMapper attachmentMapper;
    @MockitoBean AttachmentVisionMapper attachmentVisionMapper;
    @MockitoBean ChatSessionMapper chatSessionMapper;
    @MockitoBean ChatMessageMapper chatMessageMapper;
    @MockitoBean SyncChangeLogMapper syncChangeLogMapper;
    @MockitoBean com.doublez.pocketmindserver.memory.infra.persistence.MemoryRecordMapper memoryRecordMapper;
    @MockitoBean com.doublez.pocketmindserver.resource.infra.persistence.ResourceRecordMapper resourceRecordMapper;
    @MockitoBean com.doublez.pocketmindserver.context.infra.persistence.ContextCatalogMapper contextCatalogMapper;
    @MockitoBean com.doublez.pocketmindserver.context.infra.persistence.ContextRefMapper contextRefMapper;
    @MockitoBean com.doublez.pocketmindserver.asset.domain.AssetMapper assetMapper;
    @MockitoBean(name = "embeddingModel") org.springframework.ai.embedding.EmbeddingModel embeddingModel;
    @MockitoBean(name = "chatModel") org.springframework.ai.chat.model.ChatModel chatModel;

    @TestConfiguration
    static class TestOverrides {

        @Bean
        JavaMailSender javaMailSender() {
            return Mockito.mock(JavaMailSender.class);
        }

        @Bean
        org.springframework.transaction.support.TransactionTemplate transactionTemplate() {
            return Mockito.mock(org.springframework.transaction.support.TransactionTemplate.class);
        }

        @Bean
        UserAccountRepository userAccountRepository() {
            return Mockito.mock(UserAccountRepository.class);
        }

        @Bean
        ConnectionFactory connectionFactory() {
            ConnectionFactory factory = Mockito.mock(ConnectionFactory.class);
            Connection connection = Mockito.mock(Connection.class);
            Mockito.when(factory.createConnection()).thenReturn(connection);
            return factory;
        }
    }

    @Test
    void contextLoads() {
    }

}
