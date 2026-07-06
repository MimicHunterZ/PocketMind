package com.doublez.pocketmindserver.ai.application.stream;

import com.doublez.pocketmindserver.agui.AgUiEvent;
import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.ai.context.PersistingToolCallAdvisor;
import com.doublez.pocketmindserver.ai.tool.skill.TenantSkillToolResolver;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.context.application.SessionCommitService;
import com.doublez.pocketmindserver.memory.application.MemoryToolSet;
import com.doublez.pocketmindserver.resource.application.ChatTranscriptResourceSyncService;
import com.doublez.pocketmindserver.resource.application.tool.ResourceToolSet;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.tool.ToolCallback;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.publisher.Sinks;
import reactor.core.scheduler.Schedulers;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

/**
 * 聊天 SSE 回复服务。
 *
 * 负责模型流式调用、SSE 输出、消息落库与暂停/完成终态处理。
 */
@Slf4j
@Service
public class SseReplyService {

    private final AiFailoverRouter aiFailoverRouter;
    private final ChatMessageRepository chatMessageRepository;
    private final ChatStreamCancellationManager chatStreamCancellationManager;
    private final ChatSseEventFactory chatSseEventFactory;
    private final TenantSkillToolResolver tenantSkillToolResolver;
    private final ChatTranscriptResourceSyncService chatTranscriptResourceSyncService;
    private final MemoryToolSet.MemoryToolSetFactory memoryToolSetFactory;
    private final SessionCommitService sessionCommitService;
    private final ResourceToolSet.ResourceToolSetFactory resourceToolSetFactory;
    private final PersistingToolCallAdvisor persistingToolCallAdvisor;

    @Value("classpath:prompts/chat/branch_alias_system.md")
    private Resource branchAliasSystemTemplate;

    @Value("classpath:prompts/chat/branch_alias_user.md")
    private Resource branchAliasUserTemplate;

    public SseReplyService(AiFailoverRouter aiFailoverRouter,
                           ChatMessageRepository chatMessageRepository,
                           ChatStreamCancellationManager chatStreamCancellationManager,
                           ChatSseEventFactory chatSseEventFactory,
                           TenantSkillToolResolver tenantSkillToolResolver,
                           ChatTranscriptResourceSyncService chatTranscriptResourceSyncService,
                           MemoryToolSet.MemoryToolSetFactory memoryToolSetFactory,
                           SessionCommitService sessionCommitService,
                           ResourceToolSet.ResourceToolSetFactory resourceToolSetFactory,
                           PersistingToolCallAdvisor persistingToolCallAdvisor) {
        this.aiFailoverRouter = aiFailoverRouter;
        this.chatMessageRepository = chatMessageRepository;
        this.chatStreamCancellationManager = chatStreamCancellationManager;
        this.chatSseEventFactory = chatSseEventFactory;
        this.tenantSkillToolResolver = tenantSkillToolResolver;
        this.chatTranscriptResourceSyncService = chatTranscriptResourceSyncService;
        this.memoryToolSetFactory = memoryToolSetFactory;
        this.sessionCommitService = sessionCommitService;
        this.resourceToolSetFactory = resourceToolSetFactory;
        this.persistingToolCallAdvisor = persistingToolCallAdvisor;
    }

    public Flux<ServerSentEvent<String>> streamReply(long userId,
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

        UUID assistantMsgUuid = UUID.randomUUID();
        StringBuilder accumulator = new StringBuilder();
        Sinks.Many<AgUiEvent> toolEventSink = Sinks.many().multicast().onBackpressureBuffer();
        AtomicReference<String> conversationKeyRef = new AtomicReference<>();

        Flux<String> contentFlux = buildContentFlux(
                systemText, userId, sessionUuid, userMsgUuid, historyMessages, userPrompt,
                toolEventSink, conversationKeyRef);

        Flux<AgUiEvent> textEvents = contentFlux
                .doOnNext(accumulator::append)
                // contentFlux 完成时（正常结束/异常/取消）工具事件不会再有新的一轮，
                // 主动关闭 sink，否则下面的 merge 会因为 sink 永不 complete 而永远等下去。
                .doFinally(signal -> toolEventSink.tryEmitComplete())
                .map(delta -> new AgUiEvent.TextMessageContent(assistantMsgUuid.toString(), delta));

        Flux<AgUiEvent> liveEvents = Flux.merge(textEvents, toolEventSink.asFlux())
                .takeUntilOther(cancelSignal);

        Flux<AgUiEvent> preamble = Flux.just(
                new AgUiEvent.RunStarted(sessionUuid.toString(), effectiveRequestId),
                new AgUiEvent.TextMessageStart(assistantMsgUuid.toString()));

        Mono<AgUiEvent> textEnd = Mono.just(new AgUiEvent.TextMessageEnd(assistantMsgUuid.toString()));

        Mono<AgUiEvent> terminalEvent = Mono.<AgUiEvent>fromCallable(() -> {
            if (cancelled.get()) {
                return handlePausedTerminal(
                        userId, sessionUuid, userMsgUuid, assistantMsgUuid, conversationKeyRef.get(), accumulator, effectiveRequestId);
            }
            return handleDoneTerminal(
                    userId,
                    sessionUuid,
                    userMsgUuid,
                    assistantMsgUuid,
                    conversationKeyRef.get(),
                    userPrompt,
                    historyMessages,
                    isFork,
                    accumulator,
                    effectiveRequestId
            );
        }).subscribeOn(Schedulers.boundedElastic());

        return Flux.concat(preamble, liveEvents, textEnd, terminalEvent)
                .map(chatSseEventFactory::encode)
                .onErrorResume(e -> {
                    if (cancelled.get()) {
                        return Flux.just(chatSseEventFactory.paused(effectiveRequestId, null));
                    }
                    log.error("AI 流式回复异常: userId={}, sessionUuid={}", userId, sessionUuid, e);
                    // 安全修复：不向前端透传详细异常栈，避免内部凭证/路径泄露，仅返回通用错误提示
                    return Flux.just(chatSseEventFactory.runError("AI服务异常_ERR_500"));
                })
                .doFinally(signalType -> chatStreamCancellationManager.cleanup(streamKey));
    }

    public void stopReply(long userId, UUID sessionUuid, String requestId) {
        String streamKey = chatStreamCancellationManager.buildKey(userId, sessionUuid, requestId);
        boolean cancelled = chatStreamCancellationManager.cancel(streamKey, "user_stop");
        if (cancelled) {
            log.info("停止流式回复: userId={}, sessionUuid={}, requestId={}", userId, sessionUuid, requestId);
        } else {
            log.info("停止流式回复请求未命中活动流: userId={}, sessionUuid={}, requestId={}", userId, sessionUuid, requestId);
        }
    }

    private Flux<String> buildContentFlux(String systemText,
                                          long userId,
                                          UUID sessionUuid,
                                          UUID userMsgUuid,
                                          List<Message> historyMessages,
                                          String userPrompt,
                                          Sinks.Many<AgUiEvent> toolEventSink,
                                          AtomicReference<String> conversationKeyRef) {
        TenantSkillToolResolver.ResolvedTenantSkillTool resolvedSkillTool =
                tenantSkillToolResolver.resolveForUser(userId, "chat-stream");

        // 构建请求级记忆工具
        MemoryToolSet memoryToolSet = memoryToolSetFactory.createForUser(userId);
        ToolCallback[] memoryCallbacks = memoryToolSet.toToolCallbacks();

        // 构建请求级资源工具
        ResourceToolSet resourceToolSet = resourceToolSetFactory.createForUser(userId);
        ToolCallback[] resourceCallbacks = resourceToolSet.toToolCallbacks();

        List<ToolCallback> allCallbacks = new ArrayList<>();
        allCallbacks.addAll(Arrays.asList(memoryCallbacks));
        allCallbacks.addAll(Arrays.asList(resourceCallbacks));

        if (resolvedSkillTool.skillCallback() != null) {
            allCallbacks.addAll(Arrays.asList(resolvedSkillTool.skillCallback()));
        }

        return aiFailoverRouter.executeChatStream(
                "streamReply",
                client -> {
                    // 每次实际调用（含 AiFailoverRouter 的重试/降级）都生成新 key，
                    // 落库观察者据此按会话增量落库 TOOL_CALL/TOOL_RESULT、实时发工具事件。
                    String conversationKey = UUID.randomUUID().toString();
                    conversationKeyRef.set(conversationKey);

                    ChatClient.ChatClientRequestSpec requestSpec = client.prompt()
                            .toolContext(resolvedSkillTool.toolContext())
                            .system(systemText)
                            .messages(historyMessages.toArray(new Message[0]))
                            .user(userPrompt)
                            .advisors(a -> a
                                    .param(PersistingToolCallAdvisor.CTX_CONVERSATION_KEY, conversationKey)
                                    .param(PersistingToolCallAdvisor.CTX_USER_ID, userId)
                                    .param(PersistingToolCallAdvisor.CTX_SESSION_UUID, sessionUuid)
                                    .param(PersistingToolCallAdvisor.CTX_PARENT_UUID, userMsgUuid)
                                    .param(PersistingToolCallAdvisor.CTX_EVENT_SINK, toolEventSink));

                    // 注入所有合并后的工具
                    if (!allCallbacks.isEmpty()) {
                        requestSpec = requestSpec.toolCallbacks(allCallbacks.toArray(new ToolCallback[0]));
                        log.info("[tool] 对话请求注入工具: userId={}, toolCount={}", userId, allCallbacks.size());
                    } else {
                        log.info("[tool] 对话请求未注入任何工具: userId={}", userId);
                    }

                    return requestSpec.stream().content();
                }
        );
    }

    private AgUiEvent handlePausedTerminal(long userId,
                                           UUID sessionUuid,
                                           UUID userMsgUuid,
                                           UUID assistantMsgUuid,
                                           String conversationKey,
                                           StringBuilder accumulator,
                                           String requestId) {
        String partialContent = accumulator.toString();
        UUID pausedMessageUuid = null;
        if (!partialContent.isBlank()) {
            pausedMessageUuid = persistAssistant(userId, sessionUuid, userMsgUuid, assistantMsgUuid, conversationKey, partialContent);
            log.info("AI 流式回复暂停并保存部分内容: userId={}, sessionUuid={}, assistantMsgUuid={}",
                    userId, sessionUuid, pausedMessageUuid);
        } else {
            log.info("AI 流式回复暂停（无可保存增量）: userId={}, sessionUuid={}", userId, sessionUuid);
        }
        return chatSseEventFactory.pausedEvent(requestId, pausedMessageUuid);
    }

    private AgUiEvent handleDoneTerminal(long userId,
                                         UUID sessionUuid,
                                         UUID userMsgUuid,
                                         UUID assistantMsgUuid,
                                         String conversationKey,
                                         String userPrompt,
                                         List<Message> historyMessages,
                                         boolean isFork,
                                         StringBuilder accumulator,
                                         String requestId) {
        String fullContent = accumulator.toString();
        persistAssistant(userId, sessionUuid, userMsgUuid, assistantMsgUuid, conversationKey, fullContent);

        log.info("AI 流式回复完成: userId={}, sessionUuid={}, assistantMsgUuid={}",
                userId, sessionUuid, assistantMsgUuid);

        if (isFork) {
            generateBranchAliasAsync(userId, assistantMsgUuid, historyMessages, userPrompt);
        }

        // 异步触发会话提交：生成阶段摘要 + 记忆抽取
        triggerSessionCommitAsync(userId, sessionUuid);

        return new AgUiEvent.RunFinished(sessionUuid.toString(), requestId);
    }

    /**
     * 落库这轮的 assistant 回复。parentUuid 优先接在这轮工具调用链的落库尾部；
     * 若这轮没有工具调用（advisor 里查不到链尾），退回用户消息作为父节点。
     */
    private UUID persistAssistant(long userId,
                                  UUID sessionUuid,
                                  UUID userMsgUuid,
                                  UUID assistantMsgUuid,
                                  String conversationKey,
                                  String content) {
        UUID toolChainTail = conversationKey == null
                ? null
                : persistingToolCallAdvisor.getCurrentParentUuid(conversationKey);
        UUID parentUuid = toolChainTail != null ? toolChainTail : userMsgUuid;
        ChatMessageEntity assistantMsg = ChatMessageEntity.create(
                assistantMsgUuid,
                userId,
                sessionUuid,
                parentUuid,
                ChatRole.ASSISTANT,
                content,
                List.of());
        chatMessageRepository.save(assistantMsg);
        return assistantMsgUuid;
    }

    /**
     * 异步触发会话提交：生成阶段摘要并抽取记忆。
     *
     * <p>使用虚拟线程 fire-and-forget，不阻塞 SSE 响应流。
     * 失败时仅记录日志，不影响对话正常进行。
     */
    private void triggerSessionCommitAsync(long userId, UUID sessionUuid) {
        if (sessionCommitService == null) {
            log.debug("SessionCommitService 未注入，跳过会话提交: sessionUuid={}", sessionUuid);
            return;
        }
        Thread.ofVirtual().name("session-commit-" + sessionUuid)
                .start(() -> {
                    try {
                        var result = sessionCommitService.commit(userId, sessionUuid);
                        log.info("会话提交成功: userId={}, sessionUuid={}, messageCount={}, abstract={}",
                                userId, sessionUuid, result.messageCount(),
                                result.abstractText() != null && result.abstractText().length() > 60
                                        ? result.abstractText().substring(0, 60) + "…"
                                        : result.abstractText());
                    } catch (Exception e) {
                        log.warn("会话提交失败（静默忽略）: userId={}, sessionUuid={}, error={}",
                                userId, sessionUuid, e.getMessage());
                    }
                });
    }

    private void generateBranchAliasAsync(long userId,
                                          UUID assistantMsgUuid,
                                          List<Message> historyMessages,
                                          String userPrompt) {
        Schedulers.boundedElastic().schedule(() -> {
            try {
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
                    alias = alias.replaceAll("[\\p{P}\\s]", "");
                    if (alias.length() > 10) {
                        alias = alias.substring(0, 10);
                    }
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
}
