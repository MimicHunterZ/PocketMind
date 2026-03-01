package com.doublez.pocketmindserver.ai.config;

import com.fasterxml.jackson.databind.json.JsonMapper;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * AI 模块 JSON 配置。
 */
@Configuration
public class AiJsonConfiguration {

    @Bean
    public JsonMapper aiJsonMapper() {
        return JsonMapper.builder()
                .findAndAddModules()
                .build();
    }
}
