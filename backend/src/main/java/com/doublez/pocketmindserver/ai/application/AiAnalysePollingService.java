package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.api.dto.AiAnalyseAcceptRequest;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.resource.infra.http.JinaReaderClient;
import com.doublez.pocketmindserver.resource.infra.mq.CrawlerProducer;
import com.doublez.pocketmindserver.resource.infra.mq.event.CrawlerRequestEvent;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.chat.prompt.PromptTemplate;
import org.springframework.ai.chat.prompt.SystemPromptTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.core.task.TaskExecutor;
import org.springframework.stereotype.Service;
import org.springframework.util.StreamUtils;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

/**
 * AI 分析（轮询模式）应用服务。
 */
@Slf4j
@Service
public class AiAnalysePollingService {

    private final NoteRepository noteRepository;
    private final CrawlerProducer crawlerProducer;
    private final JinaReaderClient jinaReaderClient;
    private final AiFailoverRouter failoverRouter;
    private final AiAnalyseChatSessionService chatSessionService;
    private final ObjectMapper objectMapper;
    private final TaskExecutor taskExecutor;

    @Value("classpath:prompts/ai/system_prompt.md")
    private org.springframework.core.io.Resource systemPersonaResource;

    @Value("classpath:prompts/analyse/polling_template.md")
    private org.springframework.core.io.Resource pollingPromptResource;

    public AiAnalysePollingService(NoteRepository noteRepository,
                                  CrawlerProducer crawlerProducer,
                                  JinaReaderClient jinaReaderClient,
                                  AiFailoverRouter failoverRouter,
                                  AiAnalyseChatSessionService chatSessionService,
                                  ObjectMapper objectMapper,
                                  @Qualifier("applicationTaskExecutor") TaskExecutor taskExecutor) {
        this.noteRepository = noteRepository;
        this.crawlerProducer = crawlerProducer;
        this.jinaReaderClient = jinaReaderClient;
        this.failoverRouter = failoverRouter;
        this.chatSessionService = chatSessionService;
        this.objectMapper = objectMapper;
        this.taskExecutor = taskExecutor;
    }

    /**
     * 第一阶段：受理请求（写库 + 快路径触发 AI / 慢路径投递抓取 MQ）。
     */
    public void accept(String userIdStr, AiAnalyseAcceptRequest request) {
        Objects.requireNonNull(request, "request");
        long userId = parseUserId(userIdStr);

        NoteEntity note = NoteEntity.create(request.uuid(), userId);

        note.attachSourceUrl(request.url());
        note.clearSummary();

        if (request.previewTitle() != null || request.previewDescription() != null || request.hasPreviewContent()) {
            note.completeFetch(request.previewTitle(), request.previewDescription(), request.previewContent());
        } else {
            // 只标记 PENDING，等待 Consumer 更新
            note.pendingForFetch();
        }

        noteRepository.save(note);

        if (request.hasPreviewContent()) {
            taskExecutor.execute(() -> process(userIdStr, request.uuid(), request.userQuestion()));
            return;
        }

        // 慢路径：发 MQ 抓取
        crawlerProducer.sendCrawlerRequest(new CrawlerRequestEvent(request.uuid(), request.url(), userIdStr, request.userQuestion()));
    }

    /**
     * 第二/三阶段：抓取补全后或快路径触发的 AI 处理。
     */
    public void process(String userIdStr, UUID noteUuid, String userQuestion) {
        long userId = parseUserId(userIdStr);
        var noteOpt = noteRepository.findByUuidAndUserId(noteUuid, userId);
        if (noteOpt.isEmpty()) {
            log.warn("note not found for analyse, uuid={}, userId={}", noteUuid, userId);
            return;
        }
        NoteEntity note = noteOpt.get();

        String content = note.getPreviewContent();
        String title = note.getPreviewTitle();
        String description = note.getPreviewDescription();

        if (content == null || content.isBlank()) {
            try {
                var resp = jinaReaderClient.fetchContent(note.getSourceUrl());
                if (resp.code() == 200 && resp.data() != null) {
                    title = pickFirstNonBlank(title, resp.data().title());
                    description = pickFirstNonBlank(description, resp.data().description());
                    content = pickFirstNonBlank(content, resp.data().content());
                    note.completeFetch(title, description, content);
                    noteRepository.update(note);
                }
            } catch (Exception e) {
                log.warn("fetch content failed, uuid={}, url={}", noteUuid, note.getSourceUrl(), e);
            }
        }

        if (content == null || content.isBlank()) {
            note.failFetch();
            noteRepository.update(note);
            return;
        }

        Prompt prompt = buildPrompt(Map.of(
                "url", note.getSourceUrl(),
                "title", safe(title),
                "description", safe(description),
                "content", content,
                "question", safe(userQuestion)
        ));

        String text = failoverRouter.executeChat("ai-analyse-polling", client -> client.prompt(prompt).call().content());
        AnalyseResult result = parseResult(text);

        if (userQuestion != null && !userQuestion.isBlank()) {
            chatSessionService.createSessionWithMessages(note.getUuid(), userId, safe(title, note.getSourceUrl()), userQuestion,
                    buildAssistantContent(result));
        }

        note.updateSummary(result.summary());
        noteRepository.update(note);
    }

    private Prompt buildPrompt(Map<String, Object> variables) {
        try {
            // 1. 获取系统提示词（如果系统提示词是静态的，直接读成 String）
            String systemContent = StreamUtils.copyToString(
                    systemPersonaResource.getInputStream(), StandardCharsets.UTF_8);
            var systemMessage = new org.springframework.ai.chat.messages.SystemMessage(systemContent);

            // 2. 获取用户模板内容

            // 3. 将所有的 {key} 替换为 value
            String renderedUserContent = StreamUtils.copyToString(
                    pollingPromptResource.getInputStream(), StandardCharsets.UTF_8);
            for (Map.Entry<String, Object> entry : variables.entrySet()) {
                String placeholder = "{" + entry.getKey() + "}";
                String value = entry.getValue() == null ? "" : entry.getValue().toString();
                // 注意：这里使用 replace 而不是 replaceAll，避免正则转义问题
                renderedUserContent = renderedUserContent.replace(placeholder, value);
            }

            var userMessage = new org.springframework.ai.chat.messages.UserMessage(renderedUserContent);

            return new Prompt(List.of(systemMessage, userMessage));

        } catch (java.io.IOException e) {
            log.error("Failed to load prompt resource", e);
            throw new BusinessException(ApiCode.AI_RESPONSE_ERROR, HttpStatus.INTERNAL_SERVER_ERROR, "Prompt加载失败");
        }
    }

    private AnalyseResult parseResult(String text) {
        if (text == null || text.isBlank()) {
            return new AnalyseResult("", "");
        }
        try {
            return objectMapper.readValue(text, AnalyseResult.class);
        } catch (Exception ignored) {
            // 兜底：当成 summary，answer 为空
            return new AnalyseResult(text.trim(), "");
        }
    }

    private String buildAssistantContent(AnalyseResult result) {
        String summary = result.summary() == null ? "" : result.summary();
        String answer = result.answer() == null ? "" : result.answer();
        if (answer.isBlank()) {
            return summary;
        }
        return summary + "\n\n" + answer;
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }

    private String safe(String preferred, String fallback) {
        return (preferred != null && !preferred.isBlank()) ? preferred : safe(fallback);
    }

    private String pickFirstNonBlank(String a, String b) {
        if (a != null && !a.isBlank()) {
            return a;
        }
        return b;
    }

    private long parseUserId(String userId) {
        try {
            return Long.parseLong(userId);
        } catch (NumberFormatException e) {
            throw new BusinessException(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "非法 userId");
        }
    }

    public record AnalyseResult(String summary, String answer) {
    }
}
