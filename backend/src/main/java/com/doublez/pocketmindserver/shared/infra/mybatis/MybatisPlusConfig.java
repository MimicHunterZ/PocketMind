package com.doublez.pocketmindserver.shared.infra.mybatis;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.autoconfigure.ConfigurationCustomizer;
import com.baomidou.mybatisplus.core.handlers.MetaObjectHandler;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import org.apache.ibatis.reflection.MetaObject;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.UUID;

@Configuration
public class MybatisPlusConfig {

    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.POSTGRE_SQL));
        return interceptor;
    }

    @Bean
    public ConfigurationCustomizer configurationCustomizer() {
        return configuration -> {
            // Register UUID Type Handler for PostgreSQL
            configuration.getTypeHandlerRegistry().register(UUID.class, UuidTypeHandler.class);
        };
    }

    @Bean
    public MetaObjectHandler metaObjectHandler() {
        return new MetaObjectHandler() {
            @Override
            public void insertFill(MetaObject metaObject) {
                // created_at（兼容 Instant / LocalDateTime 两种模型字段类型）
                this.strictInsertFill(metaObject, "createdAt", Instant.class, Instant.now());
                this.strictInsertFill(metaObject, "createdAt", LocalDateTime.class, LocalDateTime.now());

                // updated_at（毫秒时间戳）
                this.strictInsertFill(metaObject, "updatedAt", Long.class, System.currentTimeMillis());
            }

            @Override
            public void updateFill(MetaObject metaObject) {
                this.strictUpdateFill(metaObject, "updatedAt", Long.class, System.currentTimeMillis());
            }
        };
    }
}
