package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.api.dto.AiAnalyseAcceptRequest;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.mq.CrawlerProducer;
import com.doublez.pocketmindserver.mq.event.CrawlerRequestEvent;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.core.task.TaskExecutor;
import org.springframework.stereotype.Service;

import java.util.*;

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

    @Value("classpath:prompts/analyse/system_prompt.md")
    private Resource systemTemplate;

    @Value("classpath:prompts/analyse/polling_template.md")
    private Resource pollingPrompt;

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
        Prompt prompt;
        try{
            // 使用 HashMap 防止 value 中出现 null 导致应用崩溃
            Map<String, Object> variables = new java.util.HashMap<>();
            variables.put("url", note.getSourceUrl());
            variables.put("title", safe(title));
            variables.put("description", safe(description));
            variables.put("content", content); // 即使 content 为空也不会报错
            variables.put("question", safe(userQuestion));

            prompt = PromptBuilder.build(systemTemplate,pollingPrompt, variables);
        }catch(Exception e){
            log.error("Failed to build prompt for note {}, url={}", noteUuid, note.getSourceUrl(), e);
            note.failFetch();
            noteRepository.update(note);
            return;
        }
        String text = failoverRouter.executeChat("ai-analyse-polling", client -> client.prompt(prompt).call().content());
        AnalyseResult result = parseResult(text);

        if (userQuestion != null && !userQuestion.isBlank()) {
            chatSessionService.createSessionWithMessages(note.getUuid(), userId, safe(title, note.getSourceUrl()), userQuestion,
                    result.answer);
        }

        note.updateSummary(result.summary());
        noteRepository.update(note);
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
