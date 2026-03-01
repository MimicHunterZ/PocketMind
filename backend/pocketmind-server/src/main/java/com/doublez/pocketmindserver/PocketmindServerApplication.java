package com.doublez.pocketmindserver;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication(
        scanBasePackages = {"com.doublez.pocketmindserver", "com.doublez.pocketmind.common"},
        excludeName = {
    "org.springframework.ai.model.openai.autoconfigure.OpenAiChatAutoConfiguration",
    "org.springframework.ai.model.openai.autoconfigure.OpenAiEmbeddingAutoConfiguration",
    "org.springframework.ai.model.openai.autoconfigure.OpenAiImageAutoConfiguration",
    "org.springframework.ai.model.openai.autoconfigure.OpenAiAudioSpeechAutoConfiguration",
    "org.springframework.ai.model.openai.autoconfigure.OpenAiAudioTranscriptionAutoConfiguration",
    "org.springframework.ai.model.openai.autoconfigure.OpenAiModerationAutoConfiguration"
})
@ConfigurationPropertiesScan(basePackages = {"com.doublez.pocketmindserver", "com.doublez.pocketmind.common"})
public class PocketmindServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(PocketmindServerApplication.class, args);
    }

}
