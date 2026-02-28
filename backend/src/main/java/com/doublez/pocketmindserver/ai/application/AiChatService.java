package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.ai.api.dto.chat.ChatBranchSummaryResponse;
import com.doublez.pocketmindserver.attachment.infra.persistence.vision.AttachmentVisionMapper;
import com.doublez.pocketmindserver.attachment.infra.persistence.vision.AttachmentVisionModel;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * AI 对话流式应用服务。
 * 负责：组装上下文（历史消息 + 笔记摘要 + 图片描述）→ 流式调用 AI → 持久化消息。
 */
@Slf4j
@Service
public class AiChatService {

    private final AiFailoverRouter aiFailoverRouter;
    private final ChatSessionRepository chatSessionRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final NoteRepository noteRepository;
    private final AttachmentVisionMapper attachmentVisionMapper;
    private final ChatStreamCancellationManager chatStreamCancellationManager;
    private final ChatSseEventFactory chatSseEventFactory;

    @Value("classpath:prompts/chat/global_system.md")
    private Resource globalSystemTemplate;

    @Value("classpath:prompts/chat/note_system.md")
    private Resource noteSystemTemplate;

    @Value("classpath:prompts/chat/branch_alias_system.md")
    private Resource branchAliasSystemTemplate;

    @Value("classpath:prompts/chat/branch_alias_user.md")
    private Resource branchAliasUserTemplate;

    public AiChatService(
            AiFailoverRouter aiFailoverRouter,
            ChatSessionRepository chatSessionRepository,
            ChatMessageRepository chatMessageRepository,
            NoteRepository noteRepository,
            AttachmentVisionMapper attachmentVisionMapper,
            ChatStreamCancellationManager chatStreamCancellationManager,
            ChatSseEventFactory chatSseEventFactory) {
        this.aiFailoverRouter = aiFailoverRouter;
        this.chatSessionRepository = chatSessionRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.noteRepository = noteRepository;
        this.attachmentVisionMapper = attachmentVisionMapper;
        this.chatStreamCancellationManager = chatStreamCancellationManager;
        this.chatSseEventFactory = chatSseEventFactory;
    }

    
    // 会话管理
    

    /**
     * 创建会话（全局对话或关联某篇笔记）。
     */
    public ChatSessionEntity createSession(long userId, UUID noteUuid, String title) {
        UUID sessionUuid = UUID.randomUUID();
        String finalTitle = (title == null || title.isBlank()) ? "新对话" : title;
        ChatSessionEntity session = ChatSessionEntity.create(
            sessionUuid, userId, noteUuid, finalTitle);
        chatSessionRepository.save(session);
        log.info("创建会话: userId={}, sessionUuid={}, noteUuid={}", userId, sessionUuid, noteUuid);
        return session;
    }

    /**
     * 列出当前用户的会话列表，可按笔记过滤。
     */
    public List<ChatSessionEntity> listSessions(long userId, UUID noteUuid, PageQuery pageQuery) {
        return noteUuid != null
                ? chatSessionRepository.findByNoteUuid(userId, noteUuid)
                : chatSessionRepository.findByUserId(userId, pageQuery);
    }

    /**
     * 查询单个会话详情。
     */
    public ChatSessionEntity getSession(long userId, UUID sessionUuid) {
        return validateAndGetSession(sessionUuid, userId);
    }

    /**
     * 重命名会话标题。
     */
    public void renameSession(long userId, UUID sessionUuid, String title) {
        ChatSessionEntity session = validateAndGetSession(sessionUuid, userId);
        session.updateTitle(title != null ? title : "");
        chatSessionRepository.update(session);
        log.info("重命名会话: userId={}, sessionUuid={}, title={}", userId, sessionUuid, title);
    }

    /**
     * 软删除会话。
     */
    public void deleteSession(long userId, UUID sessionUuid) {
        validateAndGetSession(sessionUuid, userId);
        chatSessionRepository.deleteByUuidAndUserId(sessionUuid, userId);
        log.info("删除会话: userId={}, sessionUuid={}", userId, sessionUuid);
    }

    /**
     * 列出会话下的消息列表。
     * 若传入 leafUuid，则返回从叶节点到链头的完整分支消息链（用于分支模式）。
     */
    public List<ChatMessageEntity> listMessages(long userId, UUID sessionUuid, UUID leafUuid) {
        validateAndGetSession(sessionUuid, userId);
        if (leafUuid != null) {
            return chatMessageRepository.findChain(leafUuid, userId);
        }
        return listMainlineMessages(userId, sessionUuid);
    }

    
    // 流式回复（入口）
    

    /**
     * 接收用户消息，流式返回 AI 回答。
     * @param parentUuid 可选。非 null 时从该节点创建新分支（链式消息历史从此节点溯源）。
     *                   null 时线性追加到当前会话末尾。
     */
    public Flux<ServerSentEvent<String>> streamReply(long userId,
                                                      UUID sessionUuid,
                                                      String userPrompt,
                                                      List<UUID> attachmentUuids,
                                                      UUID parentUuid,
                                                      String requestId) {
        // 1. 校验 session 归属
        ChatSessionEntity session = validateAndGetSession(sessionUuid, userId);

        // 2. 加载历史消息
        final List<ChatMessageEntity> history;
        final UUID effectiveParentUuid;
        if (parentUuid != null) {
            // 分支模式：从指定节点向上递归获取完整历史链
            history = chatMessageRepository.findChain(parentUuid, userId);
            effectiveParentUuid = parentUuid;
        } else {
            // 线性模式：取会话全部消息（最多 200 条）
            history = chatMessageRepository.findBySessionUuid(userId, sessionUuid, new PageQuery(200, 0));
            effectiveParentUuid = history.isEmpty() ? null : history.get(history.size() - 1).getUuid();
        }

        // 3. 构建 system prompt（含笔记上下文 + 图片识别内容）
        String systemText = buildSystemPrompt(userId, session);

        // 4. 持久化用户消息（同步落库）
        UUID userMsgUuid = UUID.randomUUID();
        ChatMessageEntity userMsg = ChatMessageEntity.create(
                userMsgUuid, userId, sessionUuid, effectiveParentUuid,
                ChatRole.USER, userPrompt, attachmentUuids);
        chatMessageRepository.save(userMsg);

        // 5. 检测分叉：若 parentUuid 非空，则本次是显式分岔操作
        final boolean isFork = (parentUuid != null);

        // 6. 构建 Spring AI 历史消息列表
        List<Message> historyMessages = toSpringAiMessages(history);

        // 7. 流式调用 AI
        return buildAndStream(userId, sessionUuid, userMsgUuid,
            userPrompt, systemText, historyMessages, isFork, requestId);
    }

    /**
     * streamReply 的无 parentUuid 重载（保持向后兼容）。
     */
    public Flux<ServerSentEvent<String>> streamReply(long userId,
                                                      UUID sessionUuid,
                                                      String userPrompt,
                                                      List<UUID> attachmentUuids) {
        return streamReply(userId, sessionUuid, userPrompt, attachmentUuids, null, UUID.randomUUID().toString());
    }

    
    // 编辑、删除、重新生成
    

    /**
     * 编辑 USER 消息并删除紧随其后的 ASSISTANT 消息。
     * 使用两次 SQL 完成：updateContent（含隐式 USER 角色校验）、softDeleteAssistantChildren。
     * 调用方（Controller）收到请求后，应随即触发一次 streamReply 以重新生成 AI 回复。
     */
    @Transactional(rollbackFor = Exception.class)
    public void editUserMessage(long userId, UUID messageUuid, String newContent) {
        // 校验：仅允许编辑当前分支末尾的 USER 消息，防止孤立下游对话链
        List<ChatMessageEntity> assistantChildren =
                chatMessageRepository.findChildrenByParentUuid(messageUuid, userId);
        for (ChatMessageEntity assistant : assistantChildren) {
            List<ChatMessageEntity> userGrandchildren =
                    chatMessageRepository.findChildrenByParentUuid(assistant.getUuid(), userId);
            if (!userGrandchildren.isEmpty()) {
                throw new BusinessException(ApiCode.REQ_VALIDATION, HttpStatus.UNPROCESSABLE_ENTITY,
                        "仅允许编辑当前分支末尾的用户消息，请先切换到目标分支");
            }
        }
        // updateContent 的 WHERE role = 'USER' 起到隐式角色校验作用
        chatMessageRepository.updateContent(messageUuid, userId, newContent);
        // 单次 SQL 清理该 USER 消息的所有 ASSISTANT 子消息
        chatMessageRepository.softDeleteAssistantChildren(messageUuid, userId);
        log.info("编辑用户消息: userId={}, messageUuid={}", userId, messageUuid);
    }

    /**
     * 重新生成 AI 回复（SSE 流式）。统一入口，按消息角色分派：
     * <ul>
     *   <li>传入 USER UUID（editAndResend 场景）：ASSISTANT 已由 editUserMessage 清除，
     *       直接复用该 USER 消息流式生成新 ASSISTANT 回复。</li>
     *   <li>传入 ASSISTANT UUID（标准重新生成）：先软删除目标 ASSISTANT，
     *       再以其父 USER 消息重新调用 AI。</li>
     * </ul>
     */
    public Flux<ServerSentEvent<String>> regenerateReply(long userId,
                                                          UUID sessionUuid,
                                                          UUID messageUuid,
                                                          String requestId) {
        ChatSessionEntity session = validateAndGetSession(sessionUuid, userId);

        ChatMessageEntity msg = chatMessageRepository.findByUuidAndUserId(messageUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "messageUuid=" + messageUuid));

        final ChatMessageEntity userMsg;
        if (msg.getRole() == ChatRole.USER) {
            // editAndResend 场景：ASSISTANT 已由 editUserMessage 软删除，直接复用该 USER 消息
            userMsg = msg;
            log.info("editAndResend 继续生成: userId={}, sessionUuid={}, userMsgUuid={}", userId, sessionUuid, messageUuid);
        } else if (msg.getRole() == ChatRole.ASSISTANT) {
            // 标准重新生成：软删除旧 ASSISTANT，找到父 USER
            UUID userMsgUuid = msg.getParentUuid();
            if (userMsgUuid == null) {
                throw new BusinessException(ApiCode.REQ_VALIDATION, HttpStatus.BAD_REQUEST,
                        "ASSISTANT 消息没有关联的 USER 消息");
            }
            chatMessageRepository.softDeleteByUuids(List.of(messageUuid), userId);
            userMsg = chatMessageRepository.findByUuidAndUserId(userMsgUuid, userId)
                    .orElseThrow(() -> new BusinessException(
                            ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "userMsgUuid=" + userMsgUuid));
            log.info("重新生成 AI 回复: userId={}, sessionUuid={}, userMsgUuid={}", userId, sessionUuid, userMsgUuid);
        } else {
            throw new BusinessException(ApiCode.REQ_VALIDATION, HttpStatus.BAD_REQUEST,
                    "仅支持对 USER 或 ASSISTANT 消息操作");
        }

        // 重建历史：从用户消息的父节点向上溯源，不含刚删的 ASSISTANT
        List<ChatMessageEntity> history = userMsg.getParentUuid() != null
                ? chatMessageRepository.findChain(userMsg.getParentUuid(), userId)
                : List.of();

        String systemText = buildSystemPrompt(userId, session);
        List<Message> historyMessages = toSpringAiMessages(history);

        return buildAndStream(userId, sessionUuid, userMsg.getUuid(),
            userMsg.getContent(), systemText, historyMessages, false, requestId);
    }

    /**
     * 停止指定 requestId 的流式回复。
     */
    public void stopReply(long userId, UUID sessionUuid, String requestId) {
        validateAndGetSession(sessionUuid, userId);
        String streamKey = chatStreamCancellationManager.buildKey(userId, sessionUuid, requestId);
        boolean cancelled = chatStreamCancellationManager.cancel(streamKey, "user_stop");
        if (cancelled) {
            log.info("停止流式回复: userId={}, sessionUuid={}, requestId={}", userId, sessionUuid, requestId);
        } else {
            log.info("停止流式回复请求未命中活动流: userId={}, sessionUuid={}, requestId={}", userId, sessionUuid, requestId);
        }
    }

    
    // 评分
    

    /**
     * 对消息评分（点赞/点踩/取消）。
     * @param rating 1=点赞，0=取消，-1=点踩
     */
    public void rateMessage(long userId, UUID messageUuid, int rating) {
        chatMessageRepository.findByUuidAndUserId(messageUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "messageUuid=" + messageUuid));
        chatMessageRepository.updateRating(messageUuid, userId, rating);
        log.info("消息评分: userId={}, messageUuid={}, rating={}", userId, messageUuid, rating);
    }

    /**
     * 更新分支别名（用户手动编辑）。
     * 长度限制由调用方（Controller @Valid）校验。
     */
    public void updateBranchAlias(long userId, UUID messageUuid, String alias) {
        chatMessageRepository.findByUuidAndUserId(messageUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "messageUuid=" + messageUuid));
        chatMessageRepository.updateBranchAlias(messageUuid, userId, alias.trim());
        log.info("更新分支别名: userId={}, messageUuid={}, alias={}", userId, messageUuid, alias);
    }

    
    // 分支管理
    

    /**
     * 获取当前会话的全部分支摘要。
     * 策略：找到所有"有多个子节点的父节点"（分叉点），对每个分叉点的子节点
     * 分别沿链追溯到最新的叶节点，提取最后一轮 USER+ASSISTANT 内容。
     * 前端通过 leafUuid 参数请求完整链消息。
     */
    public List<ChatBranchSummaryResponse> getBranches(long userId, UUID sessionUuid) {
        // 加载会话全量消息（用于分析分叉结构）
        List<ChatMessageEntity> allMessages = chatMessageRepository.findBySessionUuid(
                userId, sessionUuid, PageQuery.unbounded(1000));
        if (allMessages.isEmpty()) return List.of();

        List<ChatMessageEntity> leaves = findLeafMessages(allMessages);

        // 若只有一个叶节点，则没有分支
        if (leaves.size() <= 1) return List.of();

        // 为每个叶节点生成摘要
        return leaves.stream()
                .map(leaf -> buildBranchSummary(leaf, allMessages))
                .filter(Objects::nonNull)
                .sorted(java.util.Comparator.comparing(ChatBranchSummaryResponse::updatedAt).reversed())
                .toList();
    }

    
    // 私有核心方法
    

    /**
     * 流式调用 AI 并落库 ASSISTANT 消息的核心逻辑。
     */
    private Flux<ServerSentEvent<String>> buildAndStream(long userId,
                                                          UUID sessionUuid,
                                                          UUID userMsgUuid,
                                                          String userPrompt,
                                                          String systemText,
                                                          List<Message> historyMessages,
                                                          boolean isFork,
                                                          String requestId) {
        String effectiveRequestId = (requestId == null || requestId.isBlank())
                ? UUID.randomUUID().toString()
                : requestId;
        String streamKey = chatStreamCancellationManager.buildKey(userId, sessionUuid, effectiveRequestId);
        AtomicBoolean cancelled = new AtomicBoolean(false);
        Mono<Void> cancelSignal = chatStreamCancellationManager.listenCancel(streamKey)
                .doOnNext(reason -> {
                    cancelled.set(true);
                    log.info("检测到流式回复取消信号: userId={}, sessionUuid={}, requestId={}, reason={}",
                            userId, sessionUuid, effectiveRequestId, reason);
                })
                .then();

        StringBuilder accumulator = new StringBuilder();
        Flux<String> contentFlux = buildContentFlux(systemText, historyMessages, userPrompt);

        Mono<ServerSentEvent<String>> terminalEvent = Mono.fromCallable(() -> {
            if (cancelled.get()) {
                return handlePausedTerminal(userId, sessionUuid, userMsgUuid, accumulator, effectiveRequestId);
            }
            return handleDoneTerminal(
                    userId,
                    sessionUuid,
                    userMsgUuid,
                    userPrompt,
                    historyMessages,
                    isFork,
                    accumulator,
                    effectiveRequestId
            );
        }).subscribeOn(Schedulers.boundedElastic());

        return contentFlux
                .takeUntilOther(cancelSignal)
                .map(delta -> {
                    accumulator.append(delta);
                    return chatSseEventFactory.delta(delta);
                })
                .concatWith(terminalEvent)
                .onErrorResume(e -> {
                    if (cancelled.get()) {
                        return Flux.just(chatSseEventFactory.paused(effectiveRequestId, null));
                    }
                    log.error("AI 流式回复异常: userId={}, sessionUuid={}", userId, sessionUuid, e);
                    String safeMsg = e.getMessage() != null ? e.getMessage() : "AI 服务异常";
                    return Flux.just(chatSseEventFactory.error(safeMsg));
                })
                .doFinally(signalType -> chatStreamCancellationManager.cleanup(streamKey));
    }

    private Flux<String> buildContentFlux(String systemText,
                                          List<Message> historyMessages,
                                          String userPrompt) {
        return aiFailoverRouter.executeChatStream(
                "streamReply",
                client -> client.prompt()
                        .system(systemText)
                        .messages(historyMessages.toArray(new Message[0]))
                        .user(userPrompt)
                        .stream()
                        .content()
        );
    }

    private ServerSentEvent<String> handlePausedTerminal(long userId,
                                                          UUID sessionUuid,
                                                          UUID userMsgUuid,
                                                          StringBuilder accumulator,
                                                          String requestId) {
        String partialContent = accumulator.toString();
        UUID pausedMessageUuid = null;
        if (!partialContent.isBlank()) {
            pausedMessageUuid = persistAssistant(userId, sessionUuid, userMsgUuid, partialContent);
            log.info("AI 流式回复暂停并保存部分内容: userId={}, sessionUuid={}, assistantMsgUuid={}",
                    userId, sessionUuid, pausedMessageUuid);
        } else {
            log.info("AI 流式回复暂停（无可保存增量）: userId={}, sessionUuid={}", userId, sessionUuid);
        }
        return chatSseEventFactory.paused(requestId, pausedMessageUuid);
    }

    private ServerSentEvent<String> handleDoneTerminal(long userId,
                                                        UUID sessionUuid,
                                                        UUID userMsgUuid,
                                                        String userPrompt,
                                                        List<Message> historyMessages,
                                                        boolean isFork,
                                                        StringBuilder accumulator,
                                                        String requestId) {
        String fullContent = accumulator.toString();
        UUID assistantMsgUuid = persistAssistant(userId, sessionUuid, userMsgUuid, fullContent);

        log.info("AI 流式回复完成: userId={}, sessionUuid={}, assistantMsgUuid={}",
                userId, sessionUuid, assistantMsgUuid);

        if (isFork) {
            generateBranchAliasAsync(userId, assistantMsgUuid, userMsgUuid, historyMessages, userPrompt);
        }

        return chatSseEventFactory.done(requestId, assistantMsgUuid);
    }

    private UUID persistAssistant(long userId,
                                  UUID sessionUuid,
                                  UUID userMsgUuid,
                                  String content) {
        UUID assistantMsgUuid = UUID.randomUUID();
        ChatMessageEntity assistantMsg = ChatMessageEntity.create(
                assistantMsgUuid,
                userId,
                sessionUuid,
                userMsgUuid,
                ChatRole.ASSISTANT,
                content,
                List.of());
        chatMessageRepository.save(assistantMsg);
        return assistantMsgUuid;
    }

    /**
     * 异步生成分支别名并写入数据库。
     * 使用廉价的一次性 LLM 调用，传入 1-2 轮对话上下文。
     */
    private void generateBranchAliasAsync(long userId,
                                           UUID assistantMsgUuid,
                                           UUID userMsgUuid,
                                           List<Message> historyMessages,
                                           String userPrompt) {
        Schedulers.boundedElastic().schedule(() -> {
            try {
                // 取最近 1 轮的上下文：此前历史末尾 AI 回复（如有）
                String contextPrefix = "";
                if (!historyMessages.isEmpty()) {
                    Message last = historyMessages.get(historyMessages.size() - 1);
                    String lastText = last.getText();
                    contextPrefix = "上文：" + lastText.substring(0, Math.min(lastText.length(), 200)) + "\n";
                }
                String truncatedPrompt = userPrompt.substring(0, Math.min(userPrompt.length(), 200));

                Prompt prompt = PromptBuilder.build(
                        branchAliasSystemTemplate,
                        branchAliasUserTemplate,
                        Map.of("contextPrefix", contextPrefix, "userMessage", truncatedPrompt)
                );
                String alias = aiFailoverRouter.executeChat(
                        "branchAlias",
                        client -> client.prompt(prompt).call().content()
                );
                if (alias != null) {
                    // 截取前 8 字，去除空白/标点
                    alias = alias.replaceAll("[\\p{P}\\s]", "");
                    if (alias.length() > 10) alias = alias.substring(0, 10);
                    if (!alias.isBlank()) {
                        chatMessageRepository.updateBranchAlias(assistantMsgUuid, userId, alias);
                        log.info("分支别名生成: userId={}, messageUuid={}, alias={}", userId, assistantMsgUuid, alias);
                    }
                }
            } catch (Exception e) {
                log.warn("分支别名生成失败（静默忽略）: userId={}, messageUuid={}, error={}", userId, assistantMsgUuid, e.getMessage());
            }
        });
    }

    /**
     * 为单个叶节点构建分支摘要。
     */
    private ChatBranchSummaryResponse buildBranchSummary(ChatMessageEntity leaf,
                                                          List<ChatMessageEntity> allMessages) {
        // 沿 parentUuid 链向上找最近一轮 USER+ASSISTANT
        String lastUserContent = null;
        String lastAssistantContent = null;
        UUID cursor = leaf.getUuid();

        // 构建快速查找 map
        java.util.Map<UUID, ChatMessageEntity> msgMap = new java.util.HashMap<>();
        for (ChatMessageEntity m : allMessages) {
            msgMap.put(m.getUuid(), m);
        }

        // 向上遍历链，找最近的 ASSISTANT 和 USER
        while (cursor != null) {
            ChatMessageEntity current = msgMap.get(cursor);
            if (current == null) break;
            if (lastAssistantContent == null && current.getRole() == ChatRole.ASSISTANT) {
                lastAssistantContent = truncate(current.getContent(), 200);
            }
            if (lastUserContent == null && current.getRole() == ChatRole.USER) {
                lastUserContent = truncate(current.getContent(), 200);
            }
            if (lastUserContent != null && lastAssistantContent != null) break;
            cursor = current.getParentUuid();
        }

        return new ChatBranchSummaryResponse(
                leaf.getUuid(),
                leaf.getBranchAlias(),
                lastUserContent,
                lastAssistantContent,
                leaf.getUpdatedAt()
        );
    }

    private String truncate(String s, int maxChars) {
        if (s == null) return null;
        return s.length() > maxChars ? s.substring(0, maxChars) : s;
    }

    /**
     * 获取会话主链消息。
     *
     * 规则：当未指定 leafUuid 时，取“最后创建的叶子节点”作为当前主链叶子，
     * 并返回该叶子的完整链路，避免把多分支全量混在一起返回给前端。
     */
    private List<ChatMessageEntity> listMainlineMessages(long userId, UUID sessionUuid) {
        List<ChatMessageEntity> allMessages = chatMessageRepository.findBySessionUuid(
                userId,
                sessionUuid,
                PageQuery.unbounded(1000)
        );
        if (allMessages.isEmpty()) {
            return List.of();
        }

        List<ChatMessageEntity> leaves = findLeafMessages(allMessages);
        if (leaves.isEmpty()) {
            return allMessages;
        }

        ChatMessageEntity latestLeaf = leaves.get(leaves.size() - 1);
        return chatMessageRepository.findChain(latestLeaf.getUuid(), userId);
    }

    /**
     * 从全量消息中找出所有叶子节点（无子节点）。
     */
    private List<ChatMessageEntity> findLeafMessages(List<ChatMessageEntity> allMessages) {
        java.util.Set<UUID> parentUuids = allMessages.stream()
                .map(ChatMessageEntity::getParentUuid)
                .filter(Objects::nonNull)
                .collect(java.util.stream.Collectors.toSet());

        return allMessages.stream()
                .filter(m -> !parentUuids.contains(m.getUuid()))
                .toList();
    }

    /**
     * 校验会话归属权，不通过则抛出 404 异常。
     */
    private ChatSessionEntity validateAndGetSession(UUID sessionUuid, long userId) {
        return chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "sessionUuid=" + sessionUuid));
    }

    
    // 私有辅助方法
    

    /**
     * 构建 system prompt。
     * 有笔记上下文时渲染 prompts/chat/note_system.md，否则加载 prompts/chat/global_system.md。
     */
    private String buildSystemPrompt(long userId, ChatSessionEntity session) {
        try {
            if (session.getScopeNoteUuid() == null) {
                return globalSystemTemplate.getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
            }

            NoteEntity note = noteRepository
                    .findByUuidAndUserId(session.getScopeNoteUuid(), userId)
                    .orElse(null);

            if (note == null) {
                return globalSystemTemplate.getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
            }

            // 组装 noteContext 段落
            StringBuilder noteContext = new StringBuilder();

            if (hasText(note.getTitle())) {
                noteContext.append("**标题**: ").append(note.getTitle()).append("\n\n");
            }
            if (hasText(note.getSummary())) {
                noteContext.append("**摘要**:\n").append(note.getSummary()).append("\n\n");
            }

            // 优先使用用户手写内容，其次使用爬取内容
            String bodyContent = hasText(note.getContent())
                    ? note.getContent()
                    : note.getPreviewContent();
            if (hasText(bodyContent)) {
                noteContext.append("**正文**:\n").append(bodyContent).append("\n\n");
            }

            // 图片识别结果（status=DONE）
            List<AttachmentVisionModel> visions = attachmentVisionMapper
                    .findDoneByNoteUuid(userId, session.getScopeNoteUuid());
            List<String> imageTexts = visions.stream()
                    .map(AttachmentVisionModel::getContent)
                    .filter(Objects::nonNull)
                    .filter(c -> !c.isBlank())
                    .toList();
            if (!imageTexts.isEmpty()) {
                noteContext.append("**图片识别内容**:\n");
                for (String t : imageTexts) {
                    noteContext.append("- ").append(t).append("\n");
                }
                noteContext.append("\n");
            }

            return PromptBuilder.render(
                    noteSystemTemplate,
                    Map.of("noteContext", noteContext.toString())
            );

        } catch (IOException e) {
            throw new UncheckedIOException("加载对话系统提示词模板失败", e);
        }
    }

    /**
     * 将领域消息列表转换为 Spring AI Message 对象列表。
     * 仅转换 TEXT 类型的 USER/ASSISTANT 消息，跳过工具调用消息。
     */
    private List<Message> toSpringAiMessages(List<ChatMessageEntity> entities) {
        return entities.stream()
                .filter(e -> "TEXT".equals(e.getMessageType()))
                .filter(e -> e.getRole() == ChatRole.USER || e.getRole() == ChatRole.ASSISTANT)
                .map(e -> {
                    if (e.getRole() == ChatRole.USER) {
                        return (Message) new UserMessage(e.getContent());
                    } else {
                        return (Message) new AssistantMessage(e.getContent());
                    }
                })
                .toList();
    }

    private boolean hasText(String s) {
        return s != null && !s.isBlank();
    }
}
