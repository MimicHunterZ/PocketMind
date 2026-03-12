package com.doublez.pocketmindserver.ai.application.retrieval;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

/**
 * LlmIntentAnalyzer 单元测试 — Mock AiFailoverRouter 验证 JSON 解析逻辑。
 */
@ExtendWith(MockitoExtension.class)
class LlmIntentAnalyzerTest {

    @Mock
    private AiFailoverRouter aiFailoverRouter;

    private LlmIntentAnalyzer analyzer;

    @BeforeEach
    void setUp() {
        analyzer = new LlmIntentAnalyzer(aiFailoverRouter, new ObjectMapper());
        ReflectionTestUtils.setField(analyzer, "systemTemplate",
                new ByteArrayResource("system prompt".getBytes(StandardCharsets.UTF_8)));
        ReflectionTestUtils.setField(analyzer, "userTemplate",
                new ByteArrayResource("当前消息：<currentMessage>".getBytes(StandardCharsets.UTF_8)));
    }

    @Test
    void 正常JSON响应解析为AnalyzedIntent() {
        String llmResponse = """
                {
                  "reasoning": "用户询问 Spring Boot 配置，需要检索相关资源",
                  "queries": [
                    {"query": "Spring Boot 配置", "context_type": "resource", "intent": "查找配置文档", "priority": 1},
                    {"query": "用户的技术栈偏好", "context_type": "memory", "intent": "了解用户背景", "priority": 2}
                  ]
                }
                """;
        when(aiFailoverRouter.executeChat(eq("intent-analysis"), any())).thenReturn(llmResponse);

        AnalyzedIntent result = analyzer.analyze("Spring Boot 怎么配置数据源？");

        assertThat(result.needsRetrieval()).isTrue();
        assertThat(result.queries()).hasSize(2);
        assertThat(result.queries().get(0).query()).isEqualTo("Spring Boot 配置");
        assertThat(result.queries().get(0).contextType()).isEqualTo("resource");
        assertThat(result.queries().get(0).priority()).isEqualTo(1);
        assertThat(result.queries().get(1).contextType()).isEqualTo("memory");
        assertThat(result.reasoning()).contains("Spring Boot");
    }

    @Test
    void Markdown代码块包裹的JSON也能正确解析() {
        String llmResponse = """
                ```json
                {
                  "reasoning": "日常问候",
                  "queries": []
                }
                ```
                """;
        when(aiFailoverRouter.executeChat(eq("intent-analysis"), any())).thenReturn(llmResponse);

        AnalyzedIntent result = analyzer.analyze("你好");

        assertThat(result.needsRetrieval()).isFalse();
        assertThat(result.queries()).isEmpty();
        assertThat(result.reasoning()).isEqualTo("日常问候");
    }

    @Test
    void 空输入返回skip() {
        AnalyzedIntent result = analyzer.analyze("");

        assertThat(result.needsRetrieval()).isFalse();
        assertThat(result.queries()).isEmpty();
    }

    @Test
    void null输入返回skip() {
        AnalyzedIntent result = analyzer.analyze(null);

        assertThat(result.needsRetrieval()).isFalse();
    }

    @Test
    void LLM调用异常时降级为passthrough() {
        when(aiFailoverRouter.executeChat(eq("intent-analysis"), any()))
                .thenThrow(new RuntimeException("API 不可用"));

        AnalyzedIntent result = analyzer.analyze("测试查询");

        assertThat(result.needsRetrieval()).isTrue();
        assertThat(result.queryText()).isEqualTo("测试查询");
    }

    @Test
    void LLM返回非法JSON时降级为passthrough() {
        when(aiFailoverRouter.executeChat(eq("intent-analysis"), any()))
                .thenReturn("这不是一个有效的 JSON 响应");

        AnalyzedIntent result = analyzer.analyze("测试查询");

        assertThat(result.needsRetrieval()).isTrue();
        // 降级为 passthrough，queryText 是 LLM 的原始响应
        assertThat(result.queryText()).isNotEmpty();
    }

    @Test
    void 超长输入会被截断() {
        String longInput = "a".repeat(600);
        when(aiFailoverRouter.executeChat(eq("intent-analysis"), any()))
                .thenReturn("""
                        {"reasoning": "截断测试", "queries": [{"query": "测试", "context_type": "resource", "intent": "test", "priority": 1}]}
                        """);

        AnalyzedIntent result = analyzer.analyze(longInput);

        assertThat(result.needsRetrieval()).isTrue();
        assertThat(result.queries()).hasSize(1);
    }

    @Test
    void queries按priority排序() {
        String llmResponse = """
                {
                  "reasoning": "测试排序",
                  "queries": [
                    {"query": "低优先级", "context_type": "resource", "intent": "low", "priority": 3},
                    {"query": "高优先级", "context_type": "resource", "intent": "high", "priority": 1},
                    {"query": "中优先级", "context_type": "memory", "intent": "mid", "priority": 2}
                  ]
                }
                """;
        when(aiFailoverRouter.executeChat(eq("intent-analysis"), any())).thenReturn(llmResponse);

        AnalyzedIntent result = analyzer.analyze("排序测试");

        assertThat(result.queries()).hasSize(3);
        assertThat(result.queries().get(0).priority()).isEqualTo(1);
        assertThat(result.queries().get(1).priority()).isEqualTo(2);
        assertThat(result.queries().get(2).priority()).isEqualTo(3);
    }
}
