package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

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

    @Value("classpath:prompts/chat/global_system.md")
    private Resource globalSystemTemplate;

    @Value("classpath:prompts/chat/note_system.md")
    private Resource noteSystemTemplate;

    public AiChatService(
            AiFailoverRouter aiFailoverRouter,
            ChatSessionRepository chatSessionRepository,
            ChatMessageRepository chatMessageRepository,
            NoteRepository noteRepository,
            AttachmentVisionMapper attachmentVisionMapper) {
        this.aiFailoverRouter = aiFailoverRouter;
        this.chatSessionRepository = chatSessionRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.noteRepository = noteRepository;
        this.attachmentVisionMapper = attachmentVisionMapper;
    }

    // -------------------------------------------------------------------------
    // 流式回复
    // -------------------------------------------------------------------------

    /**
     * 接收用户消息，流式返回 AI 回复。
     * SSE 事件类型：
     * - event=delta  data=<文字片段>
     * - event=done   data={"messageUuid":"<uuid>"}
     * - event=error  data={"message":"<错误信息>"}
     */
    public Flux<ServerSentEvent<String>> streamReply(long userId,
                                                      UUID sessionUuid,
                                                      String userPrompt,
                                                      List<UUID> attachmentUuids) {
        // 1. 校验 session 归属（同步，在 MVC 线程执行）
        ChatSessionEntity session = chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "sessionUuid=" + sessionUuid));

        // 2. 加载历史消息（按时间正序，最多取 200 条）
        List<ChatMessageEntity> history = chatMessageRepository.findBySessionUuid(
                userId, sessionUuid, new PageQuery(200, 0));

        // 3. 构建 system prompt（含笔记上下文 + 图片识别内容）
        String systemText = buildSystemPrompt(userId, session);

        // 4. 持久化用户消息（同步落库）
        UUID parentUuid = history.isEmpty() ? null : history.get(history.size() - 1).getUuid();
        UUID userMsgUuid = UUID.randomUUID();
        ChatMessageEntity userMsg = ChatMessageEntity.create(
                userMsgUuid, userId, sessionUuid, parentUuid,
                ChatRole.USER, userPrompt, attachmentUuids);
        chatMessageRepository.save(userMsg);

        // 若会话尚无标题，以用户首条消息前 40 字作为标题
        if (history.isEmpty() && (session.getTitle() == null || session.getTitle().isBlank())) {
            String autoTitle = userPrompt.length() > 40
                    ? userPrompt.substring(0, 40) + "…"
                    : userPrompt;
            session.updateTitle(autoTitle);
            chatSessionRepository.update(session);
        }

        // 5. 将历史消息转换为 Spring AI Message 列表
        List<Message> historyMessages = toSpringAiMessages(history);

        // 6. 流式调用 AI
        StringBuilder accumulator = new StringBuilder();

        // 通过 AiFailoverRouter 统一调用，自动支持 primary->secondary->fallback 降级
        Flux<String> contentFlux = aiFailoverRouter.executeChatStream(
                "streamReply",
                client -> client.prompt()
                        .system(systemText)
                        .messages(historyMessages.toArray(new Message[0]))
                        .user(userPrompt)
                        .stream()
                        .content()
        );

        return contentFlux
                .map(delta -> {
                    accumulator.append(delta);
                    return ServerSentEvent.<String>builder()
                            .event("delta")
                            .data(delta)
                            .build();
                })
                .concatWith(
                        // 流结束后：持久化 ASSISTANT 消息（需要切到阻塞友好线程）
                        Mono.<ServerSentEvent<String>>fromCallable(() -> {
                            String fullContent = accumulator.toString();
                            UUID assistantMsgUuid = UUID.randomUUID();
                            ChatMessageEntity assistantMsg = ChatMessageEntity.create(
                                    assistantMsgUuid, userId, sessionUuid,
                                    userMsgUuid, ChatRole.ASSISTANT,
                                    fullContent, List.of());
                            chatMessageRepository.save(assistantMsg);

                            // 更新 session updatedAt，使其在列表中排到最前
                            session.updateTitle(session.getTitle() != null ? session.getTitle() : "");
                            chatSessionRepository.update(session);

                            log.info("AI 流式回复完成: userId={}, sessionUuid={}, assistantMsgUuid={}",
                                    userId, sessionUuid, assistantMsgUuid);

                            return ServerSentEvent.<String>builder()
                                    .event("done")
                                    .data("{\"messageUuid\":\"" + assistantMsgUuid + "\"}")
                                    .build();
                        }).subscribeOn(Schedulers.boundedElastic())
                )
                .onErrorResume(e -> {
                    log.error("AI 流式回复异常: userId={}, sessionUuid={}", userId, sessionUuid, e);
                    String safeMsg = e.getMessage() != null
                            ? e.getMessage().replace("\"", "'")
                            : "AI 服务异常";
                    return Flux.just(ServerSentEvent.<String>builder()
                            .event("error")
                            .data("{\"message\":\"" + safeMsg + "\"}")
                            .build());
                });
    }

    // -------------------------------------------------------------------------
    // 私有辅助方法
    // -------------------------------------------------------------------------

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
