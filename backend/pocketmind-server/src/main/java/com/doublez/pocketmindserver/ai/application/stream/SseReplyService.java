package com.doublez.pocketmindserver.ai.application.stream;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.ai.tool.skill.TenantSkillToolResolver;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.resource.application.ChatTranscriptResourceSyncService;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

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

    @Value("classpath:prompts/chat/branch_alias_system.md")
    private Resource branchAliasSystemTemplate;

    @Value("classpath:prompts/chat/branch_alias_user.md")
    private Resource branchAliasUserTemplate;

    public SseReplyService(AiFailoverRouter aiFailoverRouter,
                           ChatMessageRepository chatMessageRepository,
                           ChatStreamCancellationManager chatStreamCancellationManager,
                           ChatSseEventFactory chatSseEventFactory,
                           TenantSkillToolResolver tenantSkillToolResolver,
                           ChatTranscriptResourceSyncService chatTranscriptResourceSyncService) {
        this.aiFailoverRouter = aiFailoverRouter;
        this.chatMessageRepository = chatMessageRepository;
        this.chatStreamCancellationManager = chatStreamCancellationManager;
        this.chatSseEventFactory = chatSseEventFactory;
        this.tenantSkillToolResolver = tenantSkillToolResolver;
        this.chatTranscriptResourceSyncService = chatTranscriptResourceSyncService;
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

        StringBuilder accumulator = new StringBuilder();
        Flux<String> contentFlux = buildContentFlux(systemText, userId, historyMessages, userPrompt);

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
                    return Flux.just(chatSseEventFactory.error(effectiveRequestId, safeMsg));
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
                                          List<Message> historyMessages,
                                          String userPrompt) {
        TenantSkillToolResolver.ResolvedTenantSkillTool resolvedSkillTool =
                tenantSkillToolResolver.resolveForUser(userId, "chat-stream");
        return aiFailoverRouter.executeChatStream(
                "streamReply",
                client -> {
                    ChatClient.ChatClientRequestSpec requestSpec = client.prompt()
                            .toolContext(resolvedSkillTool.toolContext())
                            .system(systemText)
                            .messages(historyMessages.toArray(new Message[0]))
                            .user(userPrompt);
                    if (resolvedSkillTool.skillCallback() != null) {
                        log.info("[skill] 对话请求注入 tenant skill: userId={}, tenantKey={}, agentKey={}",
                                userId, resolvedSkillTool.tenantKey(), resolvedSkillTool.agentKey());
                        requestSpec = requestSpec.toolCallbacks(resolvedSkillTool.skillCallback());
                    } else {
                        log.info("[skill] 对话请求未注入 tenant skill（无可用技能）: userId={}, tenantKey={}, agentKey={}",
                                userId, resolvedSkillTool.tenantKey(), resolvedSkillTool.agentKey());
                    }
                    return requestSpec.stream().content();
                }
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
            generateBranchAliasAsync(userId, assistantMsgUuid, historyMessages, userPrompt);
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
            chatTranscriptResourceSyncService.syncSessionTranscript(userId, sessionUuid);
        return assistantMsgUuid;
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
