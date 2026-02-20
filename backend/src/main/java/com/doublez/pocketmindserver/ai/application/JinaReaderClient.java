package com.doublez.pocketmindserver.ai.application;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Map;

@Slf4j
@Service
public class JinaReaderClient {

    @Value("${spring.ai.alibaba.toolcalling.jinacrawler.api-key}")
    private String apiKey;

    private final RestClient restClient;
    private final ObjectMapper objectMapper;

    public JinaReaderClient(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;

        // Configure timeouts
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(30 * 1000); // 30 seconds
        factory.setReadTimeout(60 * 1000);    // 60 seconds

        this.restClient = RestClient.builder()
                .requestFactory(factory)
                .baseUrl("https://r.jina.ai")
                .defaultHeader("User-Agent", "PocketMind/1.0")
                .build();
    }

    public JinaResponse fetchContent(String url) {
        log.info("Fetching content from Jina for URL: {}", url);

        // 1. 检查 API Key
        boolean isValidKey = apiKey != null && !apiKey.isBlank() && !apiKey.equals("jina_xxx") && !apiKey.startsWith("jina_");
        if (!isValidKey) {
            log.warn("Invalid or default Jina API Key detected. Request will be sent without Authorization header.");
        }

        // 2. 检查是否为 X (Twitter) 链接
        boolean isXPlatform = url.contains("x.com") || url.contains("twitter.com");

        try {
            // 3. 构建请求规范
            var requestSpec = restClient.get()
                    .uri("/{url}", url)
                    .header("Accept", "application/json")
                    .header("X-Return-Format", "markdown");

            // 4. 针对 X 特定标签
            if (isXPlatform) {
                log.info("Detected X/Twitter URL, applying specific selectors...");
                // tweetText 用于抓正文（含长文），tweetPhoto 用于抓配图
                requestSpec.header("X-Target-Selector", "[data-testid=\"tweetText\"], [data-testid=\"tweetPhoto\"]");
                // 可选：开启 ReaderLM-v2 模型，对推文这种短文本/非标准网页结构理解更好,但是消耗更高
                // requestSpec.header("X-Use-Reader-Lmv2", "true");
            }

            // 5. 添加认证头
            if (isValidKey) {
                requestSpec.header("Authorization", "Bearer " + apiKey);
            }

            // 6. 发送请求
            ResponseEntity<String> responseEntity = requestSpec
                    .retrieve()
                    .toEntity(String.class);

            String body = responseEntity.getBody();
            if (body == null || body.isBlank()) {
                log.error("Jina returned empty body for URL: {}", url);
                throw new RuntimeException("Jina returned empty body");
            }

            try {
                return objectMapper.readValue(body, JinaResponse.class);
            } catch (Exception e) {
                log.error("Failed to parse Jina JSON response. Raw Body: {}", body);
                throw new RuntimeException("Failed to parse Jina response: " + e.getMessage(), e);
            }

        } catch (Exception e) {
            log.error("Failed to fetch content from Jina. Error: {}", e.getMessage());
            throw new RuntimeException("Jina API Error: " + e.getMessage(), e);
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record JinaResponse(
            int code,
            int status,
            JinaData data
    ) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record JinaData(
            String title,
            String url,
            String content,
            String description,
            Map<String, Object> usage,
            String publishedTime,
            Map<String, Object> metadata,
            Map<String, Object> external
    ) {
    }
}
