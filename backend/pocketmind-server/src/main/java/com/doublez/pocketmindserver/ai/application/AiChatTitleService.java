package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
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
import java.util.UUID;

/**
 * 聊天标题生成服务。
 */
@Slf4j
@Service
public class AiChatTitleService {

    private final AiFailoverRouter aiFailoverRouter;
    private final ChatSessionRepository chatSessionRepository;

    @Value("classpath:prompts/chat/session_title_system.md")
    private Resource sessionTitleSystemTemplate;

    @Value("classpath:prompts/chat/session_title_user.md")
    private Resource sessionTitleUserTemplate;

    public AiChatTitleService(AiFailoverRouter aiFailoverRouter,
                              ChatSessionRepository chatSessionRepository) {
        this.aiFailoverRouter = aiFailoverRouter;
        this.chatSessionRepository = chatSessionRepository;
    }

    /**
        * 同步生成并更新会话标题。
     */
    public String generateAndUpdateTitle(long userId,
                                         UUID sessionUuid,
                                         String userPrompt) {
        ChatSessionEntity session = chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND,
                        HttpStatus.NOT_FOUND,
                        "sessionUuid=" + sessionUuid
                ));

        String title;
        try {
            title = generateTitle(userPrompt);
        } catch (Exception e) {
            log.warn("会话标题生成失败: userId={}, sessionUuid={}, error={}", userId, sessionUuid, e.getMessage());
            throw new BusinessException(
                    ApiCode.INTERNAL_ERROR,
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "标题生成失败"
            );
        }
        if (title == null || title.isBlank()) {
            throw new BusinessException(
                    ApiCode.REQ_VALIDATION,
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "标题生成失败，content 无有效语义"
            );
        }

        chatSessionRepository.updateTitleByUuidAndUserId(sessionUuid, userId, title);
        log.info("会话标题生成完成: userId={}, sessionUuid={}, oldTitle={}, newTitle={}",
                userId, sessionUuid, session.getTitle(), title);
        return title;
    }

    private String generateTitle(String userPrompt) throws Exception {
        String promptText = truncate(userPrompt, 240);

        BeanOutputConverter<SessionTitleResult> outputConverter =
                new BeanOutputConverter<>(SessionTitleResult.class);
        OpenAiChatOptions options = OpenAiChatOptions.builder()
                .responseFormat(new ResponseFormat(
                        ResponseFormat.Type.JSON_OBJECT,
                        outputConverter.getJsonSchema()))
                .build();

        Prompt prompt = PromptBuilder.build(
                sessionTitleSystemTemplate,
                sessionTitleUserTemplate,
                Map.of(
                        "userMessage", promptText,
                        "format", outputConverter.getFormat()),
                options
        );

        SessionTitleResult result = aiFailoverRouter.executeChat(
                "sessionTitle",
                client -> client.prompt(prompt).call().entity(SessionTitleResult.class)
        );
        if (result == null || result.title() == null || result.title().isBlank()) {
            return null;
        }

        String cleaned = result.title()
                .replaceAll("[\\r\\n]+", " ")
                .replaceAll("[\"'`]+", "")
                .trim();
        if (cleaned.isBlank()) {
            return null;
        }

        if (cleaned.length() > 12) {
            cleaned = cleaned.substring(0, 12);
        }
        return cleaned;
    }

    private String truncate(String value, int maxChars) {
        if (value == null) {
            return null;
        }
        return value.length() > maxChars ? value.substring(0, maxChars) : value;
    }

    private record SessionTitleResult(String title) {
    }
}

