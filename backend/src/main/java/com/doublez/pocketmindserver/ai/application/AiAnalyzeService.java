package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.api.dto.AiAnalyzeRequest;
import com.doublez.pocketmindserver.ai.api.dto.AiAnalyzeResponse;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.chat.prompt.PromptTemplate;
import org.springframework.ai.chat.prompt.SystemPromptTemplate;
import org.springframework.ai.converter.BeanOutputConverter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.http.HttpStatus;

import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class AiAnalyzeService {

    private static final String MODE_QA = "QA";
    private static final String MODE_SUMMARY = "SUMMARY";

    private final AiFailoverRouter failoverRouter;

    private final BeanOutputConverter<PocketMindSummary> summaryConverter =
            new BeanOutputConverter<>(PocketMindSummary.class);

    private final BeanOutputConverter<PocketMindQA> qaConverter =
            new BeanOutputConverter<>(PocketMindQA.class);

    @Value("classpath:prompts/ai/system_prompt.md")
    private Resource systemPersonaResource;

    @Value("classpath:prompts/ai/qa_template.md")
    private Resource qaPromptResource;

    @Value("classpath:prompts/ai/summary_template.md")
    private Resource summaryPromptResource;

    public AiAnalyzeService(AiFailoverRouter failoverRouter) {
        this.failoverRouter = failoverRouter;
    }

    public AiAnalyzeResponse<?> analyze(AiAnalyzeRequest request, String userId) {
        String mode = request.isQaMode() ? MODE_QA : MODE_SUMMARY;
        log.info("开始 AI 分析 - userId: {}, mode: {}", userId, mode);

        try {
            Object finalResult = MODE_QA.equals(mode)
                    ? processQa(request.content(), request.userQuestion())
                    : processSummary(request.content());

            return new AiAnalyzeResponse<>(mode, request.userQuestion(), finalResult);
        } catch (Exception e) {
            log.error("AI 分析服务异常 - userId: {}, mode: {}", userId, mode, e);
            BusinessException ex = new BusinessException(
                    ApiCode.AI_RESPONSE_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "AI 分析服务暂时不可用"
            );
            ex.initCause(e);
            throw ex;
        }
    }

    /**
     * 处理问答模式 (返回 PocketMindQA 对象)
     */
    private PocketMindQA processQa(String content, String question) {
        // 1. 获取 Format 指令
        String formatInstructions = qaConverter.getFormat();

        // 2. 构建 Prompt
        Prompt prompt = buildBasePrompt(qaPromptResource, Map.of(
                "content", content,
                "question", question,
                "format", formatInstructions
        ));

        // 3. 调用 AI 获取原始文本
        String rawResponse = failoverRouter.executeChat("analyze-qa", client -> client.prompt(prompt).call().content());
        log.info("AI QA 完成 - responseLength: {}", rawResponse == null ? 0 : rawResponse.length());
        return qaConverter.convert(rawResponse);
    }

    /**
     * 处理总结模式 (返回 PocketMindSummary 对象)
     */
    private PocketMindSummary processSummary(String content) {
        // 1. 获取 Spring AI 自动生成的 Format 指令
        String formatInstructions = summaryConverter.getFormat();

        // 2. 构建 Prompt，传入内容和格式指令
        Prompt prompt = buildBasePrompt(summaryPromptResource, Map.of(
                "content", content,
                "format", formatInstructions
        ));

        // 3. 调用 AI 获取原始文本
        String rawResponse = failoverRouter.executeChat("analyze-summary", client -> client.prompt(prompt).call().content());

        // 4. 解析器自动将 JSON 字符串转为 Java Record
        log.info("AI Raw JSON: {}", rawResponse);
        return summaryConverter.convert(rawResponse);
    }

    /**
     * 通用 Prompt 构建器
     */
    private Prompt buildBasePrompt(Resource userTemplateResource, Map<String, Object> variables) {
        // System Message
        SystemPromptTemplate systemTemplate = new SystemPromptTemplate(systemPersonaResource);
        Message systemMessage = systemTemplate.createMessage();

        PromptTemplate userTemplate = new PromptTemplate(userTemplateResource);
        Message userMessage = userTemplate.createMessage(variables);

        return new Prompt(List.of(systemMessage, userMessage));
    }
}

record PocketMindSummary(
        String summary,
        List<String> tags
) {
}

record PocketMindQA(
        String answer,
        List<String> tags
) {
}
