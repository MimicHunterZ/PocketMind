package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.api.dto.AiAnalyseAcceptRequest;
import com.doublez.pocketmindserver.ai.api.dto.AiAnalysePollingResult;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.chat.application.ChatPersistenceContextHolder;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.note.domain.tag.TagRepository;
import com.doublez.pocketmindserver.note.infra.persistence.note.NoteTagRelationMapper;
import com.doublez.pocketmindserver.mq.CrawlerProducer;
import com.doublez.pocketmindserver.mq.event.CrawlerRequestEvent;
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
 * AI 鍒嗘瀽锛堣疆璇㈡ā寮忥級搴旂敤鏈嶅姟銆?
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
    private final NoteTagRelationMapper noteTagRelationMapper;
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
                                   TagRepository tagRepository,
                                   NoteTagRelationMapper noteTagRelationMapper,
                                   @Qualifier("applicationTaskExecutor") TaskExecutor taskExecutor) {
        this.noteRepository = noteRepository;
        this.crawlerProducer = crawlerProducer;
        this.jinaReaderClient = jinaReaderClient;
        this.failoverRouter = failoverRouter;
        this.chatSessionService = chatSessionService;
        this.tagRepository = tagRepository;
        this.noteTagRelationMapper = noteTagRelationMapper;
        this.taskExecutor = taskExecutor;
    }

    /**
     * 绗竴闃舵锛氬彈鐞嗚姹傦紙鍐欏簱 + 蹇矾寰勮Е鍙?AI / 鎱㈣矾寰勬姇閫掓姄鍙?MQ锛夈€?
     * 骞傜瓑璁捐锛氱瑪璁板凡瀛樺湪鏃舵墽琛?update锛屼笉瀛樺湪鏃舵墽琛?insert锛涢伩鍏嶉噸澶嶆彁浜よ繑鍥?500銆?
     */
    public void accept(String userIdStr, AiAnalyseAcceptRequest request) {
        Objects.requireNonNull(request, "request");
        long userId = parseUserId(userIdStr);

        // 骞傜瓑锛氬厛鏌ヨ锛屽瓨鍦ㄥ垯鏇存柊锛屼笉瀛樺湪鎵嶆柊寤?
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
            log.info("绗旇宸插瓨鍦紝鎵ц update: uuid={}", request.uuid());
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
        }

        if (request.hasPreviewContent()) {
            taskExecutor.execute(() -> process(
                    userIdStr,
                    request.uuid(),
                    request.userQuestion()
            ));
            return;
        }

        // 鎱㈣矾寰勶細鍙?MQ 鎶撳彇
        crawlerProducer.sendCrawlerRequest(new CrawlerRequestEvent(
            request.uuid(),
            request.url(),
            userIdStr,
            request.userQuestion()
        ));
    }

    /**
     * 绗簩/涓夐樁娈碉細鎶撳彇琛ュ叏鍚庢垨蹇矾寰勮Е鍙戠殑 AI 澶勭悊銆?
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
        try {
            // 浣跨敤 HashMap 闃叉 value 涓嚭鐜?null 瀵艰嚧搴旂敤宕╂簝
            Map<String, Object> variables = new java.util.HashMap<>();
            variables.put("url", note.getSourceUrl());
            variables.put("title", safe(title));
            variables.put("description", safe(description));
            variables.put("content", content);
            variables.put("question", safe(userQuestion));

            // format: BeanOutputConverter 鐢熸垚鐨勭粨鏋勫寲杈撳嚭鏍煎紡璇存槑锛堢敤浜庢彁绀烘ā鍨嬭緭鍑?JSON锛?
            String format = new BeanOutputConverter<>(AiAnalysePollingResult.class).getFormat();
            variables.put("format", format);

            var outputConverter = new BeanOutputConverter<>(AiAnalysePollingResult.class);
            String jsonSchema = outputConverter.getJsonSchema();
                OpenAiChatOptions options = OpenAiChatOptions.builder()
                        .responseFormat(new ResponseFormat(ResponseFormat.Type.JSON_OBJECT,jsonSchema))
                        .build();
                prompt = PromptBuilder.build(systemTemplate, pollingPrompt, variables, options);
        } catch (Exception e) {
            log.error("Failed to build prompt for note {}, url={}", noteUuid, note.getSourceUrl(), e);
            note.failFetch();
            noteRepository.update(note);
            return;
        }

        //todo 杩欓噷 mcp 搴曞眰渚濊禆 json瑙ｆ瀽锛岃繖閲岀殑渚濊禆鏈夐棶棰?
//        StructuredOutputValidationAdvisor validationAdvisor = StructuredOutputValidationAdvisor.builder()
//                .outputType(AiAnalysePollingResult.class)
//                .maxRepeatAttempts(Math.max(0, maxRepeatAttempts))
//                .advisorOrder(BaseAdvisor.HIGHEST_PRECEDENCE + 1000)
//                .build();

        AiAnalysePollingResult result;

        // 鏈夐棶棰樻椂鎵嶅垱寤轰細璇濆苟鍚敤 tool 钀藉簱
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
            // todo 澶辫触閲嶈瘯
            log.warn("AI analyse failed, skip write: noteUuid={}, url={}, err={}",
                    noteUuid, note.getSourceUrl(), e.getClass().getSimpleName());
            return;
        }

        // 鏇存柊绗旇鎽樿
        if (result.summary() != null && !result.summary().isBlank()) {
            note.updateSummary(result.summary());
            noteRepository.update(note);
        }

        // 鍐欏叆 AI 鏍囩
        writeNoteTags(userId, note.getUuid(), result.tags());

        // 钀藉簱瀵硅瘽锛坅ssistant reply锛?
        if (chatInit != null) {
            UUID parentUuid = ChatPersistenceContextHolder.getParentUuid();
            chatSessionService.saveAssistantReply(chatInit.sessionUuid(), userId, parentUuid, result.answer());
            ChatPersistenceContextHolder.clear();
        }
    }

    /**
     * 灏?AI 鐢熸垚鐨勬爣绛惧啓鍏ユ暟鎹簱锛堝箓绛夛級銆?
     */
    private void writeNoteTags(long userId, UUID noteUuid, List<String> tags) {
        if (tags == null || tags.isEmpty()) {
            return;
        }
        for (String tagName : tags) {
            if (tagName == null || tagName.isBlank()) {
                continue;
            }
            try {
                var tagEntity = tagRepository.findOrCreate(userId, tagName.trim());
                noteTagRelationMapper.insert(noteUuid, tagEntity.getId());
            } catch (Exception e) {
                // 鏍囩鍐欏叆澶辫触涓嶅奖鍝嶄富娴佺▼
                log.warn("tag write failed, noteUuid={}, tag={}", noteUuid, tagName, e);
            }
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
            throw new BusinessException(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "闈炴硶 userId");
        }
    }

}


