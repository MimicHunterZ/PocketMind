package com.doublez.pocketmindserver.context.application;

import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.context.domain.ContextCatalogRepository;
import com.doublez.pocketmindserver.context.domain.ContextUri;
import com.doublez.pocketmindserver.memory.application.MemoryExtractorService;
import com.doublez.pocketmindserver.resource.application.ChatTranscriptResourceSyncService;
import com.doublez.pocketmindserver.resource.application.ResourceContextService;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxConstants;
import com.doublez.pocketmindserver.resource.domain.ResourceIndexOutboxRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordEntity;
import com.doublez.pocketmindserver.resource.domain.ResourceRecordRepository;
import com.doublez.pocketmindserver.resource.domain.ResourceSourceType;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionOperations;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.stream.Collectors;

/**
 * 会话提交服务实现 — 将对话压缩为结构化摘要并持久化到上下文体系。
 *
 * <p>流程：
 * <ol>
 *   <li>加载会话 + 消息</li>
 *   <li>同步对话转录 Resource（CHAT_TRANSCRIPT）</li>
 *   <li>调用 LLM 生成结构化摘要</li>
 *   <li>创建 CHAT_STAGE_SUMMARY Resource → 同步 context_catalog</li>
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
    private final ResourceIndexOutboxRepository outboxRepository;
    private final ContextCatalogRepository contextCatalogRepository;
    private final SessionSummaryGenerator sessionSummaryGenerator;
    private final MemoryExtractorService memoryExtractorService;
    private final TransactionOperations transactionOperations;

    /** 对话转录消息条目模板 */
    @Value("classpath:prompts/chat/transcript_message.md")
    private Resource transcriptMessageTemplate;

    public SessionCommitServiceImpl(ChatSessionRepository chatSessionRepository,
                                    ChatMessageRepository chatMessageRepository,
                                    ChatTranscriptResourceSyncService transcriptSyncService,
                                    ResourceRecordRepository resourceRecordRepository,
                                    ResourceContextService resourceContextService,
                                    ResourceIndexOutboxRepository outboxRepository,
                                    ContextCatalogRepository contextCatalogRepository,
                                    SessionSummaryGenerator sessionSummaryGenerator,
                                    MemoryExtractorService memoryExtractorService,
                                    TransactionOperations transactionOperations) {
        this.chatSessionRepository = chatSessionRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.transcriptSyncService = transcriptSyncService;
        this.resourceRecordRepository = resourceRecordRepository;
        this.resourceContextService = resourceContextService;
        this.outboxRepository = outboxRepository;
        this.contextCatalogRepository = contextCatalogRepository;
        this.sessionSummaryGenerator = sessionSummaryGenerator;
        this.memoryExtractorService = memoryExtractorService;
        this.transactionOperations = transactionOperations;
    }

    @Override
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

        // 5. 调用 LLM 生成结构化摘要（事务外执行）
        SessionSummaryGenerator.SummaryResult summaryResult =
                sessionSummaryGenerator.generate(sessionTitle, truncatedTranscript);

        // 6. 落库阶段（事务内）
        ResourceRecordEntity summaryResource = persistSummaryResourceTx(
                userId,
                sessionUuid,
                sessionTitle,
                summaryResult.abstractText(),
                summaryResult.summaryText(),
                transcript
        );

        log.info("会话提交完成: userId={}, sessionUuid={}, messageCount={}, abstract={}",
                userId, sessionUuid, messages.size(),
                truncate(summaryResult.abstractText(), 60));

        SessionCommitResult result = new SessionCommitResult(
                sessionUuid,
                transcriptResource != null ? transcriptResource.getUuid() : null,
                summaryResource.getUuid(),
                messages.size(),
                summaryResult.abstractText()
        );

        // 9. 异步触发记忆抽取
        final SessionCommitResult commitResult = result;
        Thread.ofVirtual().name("memory-extract-" + sessionUuid)
                .start(() -> {
                    try {
                        int extracted = memoryExtractorService.extractFromCommit(userId, sessionUuid, commitResult);
                        log.info("记忆异步抽取完成: userId={}, sessionUuid={}, extracted={}",
                                userId, sessionUuid, extracted);
                    } catch (Exception e) {
                        log.error("记忆异步抽取失败: userId={}, sessionUuid={}, error={}",
                                userId, sessionUuid, e.getMessage(), e);
                    }
                });

        return result;
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

    private ResourceRecordEntity persistSummaryResourceTx(long userId,
                                                          UUID sessionUuid,
                                                          String title,
                                                          String abstractText,
                                                          String summaryText,
                                                          String fullTranscript) {
        return transactionOperations.execute(status -> {
            ContextUri summaryUri = resourceContextService.chatStageSummaryResource(userId, sessionUuid);
            ResourceRecordEntity resource = createOrUpdateSummaryResource(
                    userId,
                    sessionUuid,
                    summaryUri,
                    title,
                    abstractText,
                    summaryText,
                    fullTranscript
            );
            contextCatalogRepository.incrementActiveCount(summaryUri.value());
            return resource;
        });
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
            outboxRepository.appendPending(
                    UUID.randomUUID(),
                    userId,
                    existing.getUuid(),
                    ResourceIndexOutboxConstants.OPERATION_UPSERT
            );
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
        outboxRepository.appendPending(
                UUID.randomUUID(),
                userId,
                resource.getUuid(),
                ResourceIndexOutboxConstants.OPERATION_UPSERT
        );
        return resource;
    }

    private String renderTranscript(List<ChatMessageEntity> messages) {
        return messages.stream()
                .map(message -> {
                    try {
                        return PromptBuilder.render(transcriptMessageTemplate, Map.of(
                                "role", message.getRole() == ChatRole.USER ? "用户" : "助手",
                                "content", message.getContent()
                        ));
                    } catch (IOException e) {
                        throw new UncheckedIOException(e);
                    }
                })
                .collect(Collectors.joining("\n"));
    }

    private String truncate(String value, int maxChars) {
        if (value == null) return "";
        return value.length() > maxChars ? value.substring(0, maxChars) + "…" : value;
    }

}
