package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.api.dto.AiAnalyseAcceptRequest;
import com.doublez.pocketmindserver.ai.api.dto.AiAnalysePollingResult;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.chat.application.ChatPersistenceContextHolder;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.note.domain.tag.TagRepository;
import com.doublez.pocketmindserver.mq.CrawlerProducer;
import com.doublez.pocketmindserver.mq.event.CrawlerRequestEvent;
import com.doublez.pocketmindserver.resource.application.NoteResourceSyncService;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.advisor.StructuredOutputValidationAdvisor;
import org.springframework.ai.chat.client.advisor.api.BaseAdvisor;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.converter.BeanOutputConverter;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.ResponseFormat;
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
    private final TagRepository tagRepository;
    private final TaskExecutor taskExecutor;
    private final NoteResourceSyncService noteResourceSyncService;

    @Value("classpath:prompts/analyse/system_prompt.md")
    private Resource systemTemplate;

    @Value("classpath:prompts/analyse/polling_template.md")
    private Resource pollingPrompt;

    public AiAnalysePollingService(NoteRepository noteRepository,
                                   CrawlerProducer crawlerProducer,
                                   JinaReaderClient jinaReaderClient,
                                   AiFailoverRouter failoverRouter,
                                   AiAnalyseChatSessionService chatSessionService,
                                   TagRepository tagRepository,
                                   @Qualifier("applicationTaskExecutor") TaskExecutor taskExecutor,
                                   NoteResourceSyncService noteResourceSyncService) {
        this.noteRepository = noteRepository;
        this.crawlerProducer = crawlerProducer;
        this.jinaReaderClient = jinaReaderClient;
        this.failoverRouter = failoverRouter;
        this.chatSessionService = chatSessionService;
        this.tagRepository = tagRepository;
        this.taskExecutor = taskExecutor;
        this.noteResourceSyncService = noteResourceSyncService;
    }

    /**
        * 第一阶段：受理请求（写库 + 快路径触发 AI / 慢路径投递抓取 MQ）。
        * 幂等设计：笔记已存在时执行 update，不存在时执行 insert，避免重复提交返回 500。
     */
    public void accept(String userIdStr, AiAnalyseAcceptRequest request) {
        Objects.requireNonNull(request, "request");
        long userId = parseUserId(userIdStr);

        // 幂等：先查询，存在则更新，不存在才新建
        Optional<NoteEntity> existingOpt = noteRepository.findByUuidAndUserId(request.uuid(), userId);
        NoteEntity note;
        if (existingOpt.isPresent()) {
            note = existingOpt.get();
            note.attachSourceUrl(request.url());
            note.clearSummary();
            if (request.previewTitle() != null || request.previewDescription() != null || request.hasPreviewContent()) {
                note.completeFetch(request.previewTitle(), request.previewDescription(), request.previewContent());
            }
            noteRepository.update(note);
            noteResourceSyncService.syncProjectedResources(note);
            log.info("笔记已存在，执行 update: uuid={}", request.uuid());
        } else {
            note = NoteEntity.create(request.uuid(), userId);
            note.attachSourceUrl(request.url());
            note.clearSummary();

            if ((request.title() != null && !request.title().isBlank())
                    || (request.content() != null && !request.content().isBlank())) {
                note.updateContent(request.title(), request.content());
            }

            if (request.previewTitle() != null || request.previewDescription() != null || request.hasPreviewContent()) {
                note.completeFetch(request.previewTitle(), request.previewDescription(), request.previewContent());
            } else {
                note.pendingForFetch();
            }
            noteRepository.save(note);
            noteResourceSyncService.syncProjectedResources(note);
        }

        if (request.hasPreviewContent()) {
            taskExecutor.execute(() -> process(
                    userIdStr,
                    request.uuid(),
                    request.userQuestion()
            ));
            return;
        }

        // 慢路径：走 MQ 抓取
        crawlerProducer.sendCrawlerRequest(new CrawlerRequestEvent(
                request.uuid(),
                request.url(),
                userIdStr,
                request.userQuestion()
        ));
    }

    /**
        * 第二/三阶段：抓取补全后或快路径触发的 AI 处理。
     */
    public void process(String userIdStr,
                        UUID noteUuid,
                        String userQuestion) {
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
                    noteResourceSyncService.syncProjectedResources(note);
                }
            } catch (Exception e) {
                log.warn("fetch content failed, uuid={}, url={}", noteUuid, note.getSourceUrl(), e);
            }
        }

        if (content == null || content.isBlank()) {
            note.failFetch();
            noteRepository.update(note);
            noteResourceSyncService.syncProjectedResources(note);
            return;
        }

        Prompt prompt;
        try {
            // 使用 HashMap 防止 value 中出现 null 导致应用崩溃
            Map<String, Object> variables = new java.util.HashMap<>();
            variables.put("url", note.getSourceUrl());
            variables.put("title", safe(title));
            variables.put("description", safe(description));
            variables.put("content", content);
            variables.put("question", safe(userQuestion));

            // format: BeanOutputConverter 生成的结构化输出格式说明（用于提示模型输出 JSON）
            String format = new BeanOutputConverter<>(AiAnalysePollingResult.class).getFormat();
            variables.put("format", format);

            var outputConverter = new BeanOutputConverter<>(AiAnalysePollingResult.class);
            String jsonSchema = outputConverter.getJsonSchema();
            OpenAiChatOptions options = OpenAiChatOptions.builder()
                .responseFormat(new ResponseFormat(ResponseFormat.Type.JSON_OBJECT, jsonSchema))
                .build();
            prompt = PromptBuilder.build(systemTemplate, pollingPrompt, variables, options);
        } catch (Exception e) {
            log.error("Failed to build prompt for note {}, url={}", noteUuid, note.getSourceUrl(), e);
            note.failFetch();
            noteRepository.update(note);
            noteResourceSyncService.syncProjectedResources(note);
            return;
        }

        // todo: 这里 mcp 底层依赖 json 解析，这里的依赖仍有问题待排查
//        StructuredOutputValidationAdvisor validationAdvisor = StructuredOutputValidationAdvisor.builder()
//                .outputType(AiAnalysePollingResult.class)
//                .maxRepeatAttempts(Math.max(0, maxRepeatAttempts))
//                .advisorOrder(BaseAdvisor.HIGHEST_PRECEDENCE + 1000)
//                .build();

        AiAnalysePollingResult result;

        // 有问题时才创建会话并启用 tool 落库
        AiAnalyseChatSessionService.ChatInit chatInit = null;
        if (userQuestion != null && !userQuestion.isBlank()) {
            chatInit = chatSessionService.initSessionWithUserMessage(
                    note.getUuid(),
                    userId,
                    safe(title, note.getSourceUrl()),
                    userQuestion
            );
            ChatPersistenceContextHolder.set(userId, chatInit.sessionUuid(), chatInit.userMessageUuid());
        }

        try {
            result = failoverRouter.executeChat(
                    "ai-analyse-polling",
                    client -> client.prompt(prompt)
                            .call()
                            .entity(AiAnalysePollingResult.class)
            );
        } catch (RuntimeException e) {
            if (chatInit != null) {
                ChatPersistenceContextHolder.clear();
            }
            // todo 失败重试
            log.warn("AI analyse failed, skip write: noteUuid={}, url={}, err={}",
                    noteUuid, note.getSourceUrl(), e.getClass().getSimpleName());
            return;
        }

        // 更新笔记摘要
        if (result.summary() != null && !result.summary().isBlank()) {
            note.updateSummary(result.summary());
            noteRepository.update(note);
            noteResourceSyncService.syncProjectedResources(note);
        }

        // 写入 AI 标签
        writeNoteTags(userId, note.getUuid(), result.tags());

        // 落库对话（assistant reply）
        if (chatInit != null) {
            UUID parentUuid = ChatPersistenceContextHolder.getParentUuid();
            chatSessionService.saveAssistantReply(chatInit.sessionUuid(), userId, parentUuid, result.answer());
            ChatPersistenceContextHolder.clear();
        }
    }

    /**
     * 将 AI 生成的标签写入数据库（幂等）。
     */
    private void writeNoteTags(long userId, UUID noteUuid, List<String> tags) {
        if (tags == null || tags.isEmpty()) {
            return;
        }
        try {
            List<String> existingTags = noteRepository.findTagNamesByUuid(noteUuid, userId);
            Set<String> newTags = new HashSet<>(existingTags);
            for (String tagName : tags) {
                if (tagName != null && !tagName.isBlank()) {
                    newTags.add(tagName.trim());
                }
            }
            noteRepository.replaceTagNames(noteUuid, userId, new ArrayList<>(newTags));
        } catch (Exception e) {
            // 标签写入失败不影响主流程
            log.warn("tag write failed, noteUuid={}", noteUuid, e);
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

}


