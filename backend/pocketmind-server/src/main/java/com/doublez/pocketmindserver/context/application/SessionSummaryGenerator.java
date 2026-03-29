package com.doublez.pocketmindserver.context.application;

import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.converter.BeanOutputConverter;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.ResponseFormat;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * 会话摘要生成器。
 */
@Slf4j
@Service
public class SessionSummaryGenerator {

    private final AiFailoverRouter aiFailoverRouter;

    @Value("classpath:prompts/compression/structured_summary_system.md")
    private Resource summarySystemTemplate;

    @Value("classpath:prompts/compression/structured_summary_user.md")
    private Resource summaryUserTemplate;

    public SessionSummaryGenerator(AiFailoverRouter aiFailoverRouter) {
        this.aiFailoverRouter = aiFailoverRouter;
    }

    public SummaryResult generate(String sessionTitle, String transcript) {
        BeanOutputConverter<SummaryResult> outputConverter =
                new BeanOutputConverter<>(SummaryResult.class);

        OpenAiChatOptions options = OpenAiChatOptions.builder()
                .responseFormat(new ResponseFormat(
                        ResponseFormat.Type.JSON_OBJECT,
                        outputConverter.getJsonSchema()))
                .build();

        try {
            Prompt prompt = PromptBuilder.build(
                    summarySystemTemplate,
                    summaryUserTemplate,
                    Map.of(
                            "sessionTitle", sessionTitle,
                            "transcript", transcript,
                            "format", outputConverter.getFormat()
                    ),
                    options
            );

            SummaryResult result = aiFailoverRouter.executeChat(
                    "sessionCommitSummary",
                    client -> client.prompt(prompt).call().entity(SummaryResult.class)
            );
            if (result == null || result.abstractText() == null || result.abstractText().isBlank()) {
                log.warn("LLM 返回空摘要，使用默认值");
                return new SummaryResult("对话摘要生成失败", "无法生成结构化概览。");
            }
            return result;
        } catch (Exception e) {
            log.error("LLM 结构化摘要生成失败: {}", e.getMessage(), e);
            throw new BusinessException(
                    ApiCode.INTERNAL_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "AI 摘要生成失败"
            );
        }
    }

    /**
     * 摘要结果。
     */
    public record SummaryResult(String abstractText, String summaryText) {
    }
}
