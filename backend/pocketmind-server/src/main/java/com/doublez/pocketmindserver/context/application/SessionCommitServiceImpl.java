package com.doublez.pocketmindserver.context.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextRefEntity;
import com.doublez.pocketmindserver.context.domain.ContextRefRepository;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.resource.application.ChatTranscriptResourceSyncService;
import com.doublez.pocketmindserver.resource.application.ResourceCatalogSyncService;
import com.doublez.pocketmindserver.resource.application.ResourceContextService;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
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
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 会话提交服务实现 — 将对话压缩为结构化摘要并持久化到上下文体系。
 *
 * <p>流程：
 * <ol>
 *   <li>加载会话 + 消息</li>
 *   <li>同步对话转录 Resource（CHAT_TRANSCRIPT）</li>
 *   <li>调用 LLM 生成结构化摘要</li>
 *   <li>创建 CHAT_STAGE_SUMMARY Resource → 同步 context_catalog</li>
 *   <li>写入 ContextRef 关联</li>
 *   <li>递增 catalog 热度</li>
 * </ol>
 */
@Slf4j
@Service
public class SessionCommitServiceImpl implements SessionCommitService {

    private static final int MAX_TRANSCRIPT_CHARS = 8000;

    private final ChatSessionRepository chatSessionRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final ChatTranscriptResourceSyncService transcriptSyncService;
    private final ResourceRecordRepository resourceRecordRepository;
    private final ResourceContextService resourceContextService;
    private final ResourceCatalogSyncService catalogSyncService;
    private final ContextRefRepository contextRefRepository;
    private final ContextCatalogRepository contextCatalogRepository;
    private final AiFailoverRouter aiFailoverRouter;

    @Value("classpath:prompts/compression/structured_summary_system.md")
    private Resource summarySystemTemplate;

    @Value("classpath:prompts/compression/structured_summary_user.md")
    private Resource summaryUserTemplate;

    public SessionCommitServiceImpl(ChatSessionRepository chatSessionRepository,
                                    ChatMessageRepository chatMessageRepository,
                                    ChatTranscriptResourceSyncService transcriptSyncService,
                                    ResourceRecordRepository resourceRecordRepository,
                                    ResourceContextService resourceContextService,
                                    ResourceCatalogSyncService catalogSyncService,
                                    ContextRefRepository contextRefRepository,
                                    ContextCatalogRepository contextCatalogRepository,
                                    AiFailoverRouter aiFailoverRouter) {
        this.chatSessionRepository = chatSessionRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.transcriptSyncService = transcriptSyncService;
        this.resourceRecordRepository = resourceRecordRepository;
        this.resourceContextService = resourceContextService;
        this.catalogSyncService = catalogSyncService;
        this.contextRefRepository = contextRefRepository;
        this.contextCatalogRepository = contextCatalogRepository;
        this.aiFailoverRouter = aiFailoverRouter;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public SessionCommitResult commit(long userId, UUID sessionUuid) {
        // 1. 加载会话
        ChatSessionEntity session = chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND,
                        HttpStatus.NOT_FOUND,
                        "会话不存在: sessionUuid=" + sessionUuid
                ));

        // 2. 加载消息并过滤
        List<ChatMessageEntity> messages = loadFilteredMessages(userId, sessionUuid);
        if (messages.isEmpty()) {
            throw new BusinessException(
                    ApiCode.REQ_VALIDATION,
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "会话无有效消息，无法生成摘要"
            );
        }

        // 3. 确保对话转录 Resource 已同步
        transcriptSyncService.syncSessionTranscript(userId, sessionUuid);

        // 查找已同步的 transcript resource
        ResourceRecordEntity transcriptResource = findTranscriptResource(userId, sessionUuid);

        // 4. 渲染 transcript 文本并截断（避免 LLM token 超限）
        String transcript = renderTranscript(messages);
        String truncatedTranscript = truncate(transcript, MAX_TRANSCRIPT_CHARS);

        String sessionTitle = session.getTitle() != null && !session.getTitle().isBlank()
                ? session.getTitle() : "未命名对话";

        // 5. 调用 LLM 生成结构化摘要
        StructuredSummaryResult summaryResult = generateStructuredSummary(sessionTitle, truncatedTranscript);

        // 6. 创建 CHAT_STAGE_SUMMARY Resource
        ContextUri summaryUri = resourceContextService.chatStageSummaryResource(userId, sessionUuid);
        ResourceRecordEntity summaryResource = createOrUpdateSummaryResource(
                userId, sessionUuid, summaryUri, sessionTitle,
                summaryResult.abstractText(), summaryResult.summaryText(), transcript
        );

        // 7. 创建 ContextRef 关联（会话 → 摘要资源）
        ContextRefEntity ref = ContextRefEntity.ofSession(
                userId,
                summaryUri,
                sessionUuid,
                "CHAT_STAGE_SUMMARY"
        );
        contextRefRepository.upsert(ref);

        // 8. 递增 catalog 热度
        contextCatalogRepository.incrementActiveCount(summaryUri.value());

        log.info("会话提交完成: userId={}, sessionUuid={}, messageCount={}, abstract={}",
                userId, sessionUuid, messages.size(),
                truncate(summaryResult.abstractText(), 60));

        return new SessionCommitResult(
                sessionUuid,
                transcriptResource != null ? transcriptResource.getUuid() : null,
                summaryResource.getUuid(),
                messages.size(),
                summaryResult.abstractText()
        );
    }

    // ─── 内部方法 ──────────────────────────────────────────────────

    /**
     * 加载并过滤有效消息（TEXT 类型、USER/ASSISTANT 角色、非空内容）。
     */
    private List<ChatMessageEntity> loadFilteredMessages(long userId, UUID sessionUuid) {
        return chatMessageRepository.findBySessionUuid(userId, sessionUuid, PageQuery.unbounded(1000))
                .stream()
                .filter(m -> !m.isDeleted())
                .filter(m -> "TEXT".equals(m.getMessageType()))
                .filter(m -> m.getRole() == ChatRole.USER || m.getRole() == ChatRole.ASSISTANT)
                .filter(m -> m.getContent() != null && !m.getContent().isBlank())
                .toList();
    }

    /**
     * 查找已有的 transcript 资源。
     */
    private ResourceRecordEntity findTranscriptResource(long userId, UUID sessionUuid) {
        return resourceRecordRepository.findBySessionUuid(userId, sessionUuid).stream()
                .filter(r -> r.getSourceType() == ResourceSourceType.CHAT_TRANSCRIPT)
                .filter(r -> !r.isDeleted())
                .findFirst()
                .orElse(null);
    }

    /**
     * 调用 LLM 生成结构化摘要。
     */
    private StructuredSummaryResult generateStructuredSummary(String sessionTitle, String transcript) {
        BeanOutputConverter<StructuredSummaryResult> outputConverter =
                new BeanOutputConverter<>(StructuredSummaryResult.class);

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

            StructuredSummaryResult result = aiFailoverRouter.executeChat(
                    "sessionCommitSummary",
                    client -> client.prompt(prompt).call().entity(StructuredSummaryResult.class)
            );
            if (result == null || result.abstractText() == null || result.abstractText().isBlank()) {
                log.warn("LLM 返回空摘要，使用默认值");
                return new StructuredSummaryResult("对话摘要生成失败", "无法生成结构化概览。");
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
     * 创建或更新 CHAT_STAGE_SUMMARY 资源。
     */
    private ResourceRecordEntity createOrUpdateSummaryResource(long userId,
                                                               UUID sessionUuid,
                                                               ContextUri summaryUri,
                                                               String title,
                                                               String abstractText,
                                                               String summaryText,
                                                               String fullTranscript) {
        // 查找已有的 summary 资源
        ResourceRecordEntity existing = resourceRecordRepository.findBySessionUuid(userId, sessionUuid).stream()
                .filter(r -> r.getSourceType() == ResourceSourceType.CHAT_STAGE_SUMMARY)
                .filter(r -> !r.isDeleted())
                .findFirst()
                .orElse(null);

        if (existing != null) {
            existing.updateContent(title, fullTranscript);
            existing.updateAbstractText(abstractText);
            existing.updateSummaryText(summaryText);
            resourceRecordRepository.update(existing);
            catalogSyncService.syncToCatalog(existing);
            return existing;
        }

        ResourceRecordEntity resource = ResourceRecordEntity.createChatStageSummary(
                UUID.randomUUID(),
                userId,
                sessionUuid,
                summaryUri,
                title,
                abstractText,
                summaryText,
                fullTranscript
        );
        resourceRecordRepository.save(resource);
        catalogSyncService.syncToCatalog(resource);
        return resource;
    }

    private String renderTranscript(List<ChatMessageEntity> messages) {
        StringBuilder builder = new StringBuilder();
        for (ChatMessageEntity message : messages) {
            if (message.getRole() == ChatRole.USER) {
                builder.append("用户：");
            } else {
                builder.append("助手：");
            }
            builder.append(message.getContent()).append("\n\n");
        }
        return builder.toString().trim();
    }

    private String truncate(String value, int maxChars) {
        if (value == null) return "";
        return value.length() > maxChars ? value.substring(0, maxChars) + "…" : value;
    }

    /**
     * LLM 输出的结构化摘要结果。
     */
    record StructuredSummaryResult(String abstractText, String summaryText) {
    }
}
