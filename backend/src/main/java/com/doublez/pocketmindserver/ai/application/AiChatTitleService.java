package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.converter.BeanOutputConverter;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.ResponseFormat;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.UUID;

/**
 * 聊天标题旁路生成服务。
 *
 * 采用虚拟线程异步调用模型，生成标题后更新数据库并通过 SSE 控制帧下发。
 */
@Slf4j
@Service
public class AiChatTitleService {

    private final AiFailoverRouter aiFailoverRouter;
    private final ChatSessionRepository chatSessionRepository;
    private final SseEventSinkManager sseEventSinkManager;

    @Value("classpath:prompts/chat/session_title_system.md")
    private Resource sessionTitleSystemTemplate;

    @Value("classpath:prompts/chat/session_title_user.md")
    private Resource sessionTitleUserTemplate;

    public AiChatTitleService(AiFailoverRouter aiFailoverRouter,
                              ChatSessionRepository chatSessionRepository,
                              SseEventSinkManager sseEventSinkManager) {
        this.aiFailoverRouter = aiFailoverRouter;
        this.chatSessionRepository = chatSessionRepository;
        this.sseEventSinkManager = sseEventSinkManager;
    }

    /**
     * 异步生成标题并发布 title_update 控制帧。
     */
    public void generateAndPublishTitleAsync(long userId,
                                             UUID sessionUuid,
                                             String userPrompt) {
        Thread.ofVirtual().name("chat-title-" + sessionUuid).start(() -> {
            try {
                String title = generateTitle(userPrompt);
                if (title == null || title.isBlank()) {
                    return;
                }

                String chatId = sessionUuid.toString();
                if (!sseEventSinkManager.isSinkActive(chatId)) {
                    log.info("标题旁路流已关闭，放弃落库: userId={}, sessionUuid={}", userId, sessionUuid);
                    return;
                }

                chatSessionRepository.updateTitleByUuidAndUserId(sessionUuid, userId, title);

                if (!sseEventSinkManager.isSinkActive(chatId)) {
                    log.info("标题旁路流已关闭，放弃推送: userId={}, sessionUuid={}", userId, sessionUuid);
                    return;
                }

                sseEventSinkManager.pushTitleEvent(chatId, title);
                log.info("会话标题旁路生成完成: userId={}, sessionUuid={}, title={}",
                        userId, sessionUuid, title);
            } catch (Exception e) {
                log.warn("会话标题旁路生成失败（静默忽略）: userId={}, sessionUuid={}, error={}",
                        userId, sessionUuid, e.getMessage());
            }
        });
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
