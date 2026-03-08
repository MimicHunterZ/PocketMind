package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.application.context.ContextAssembler;
import com.doublez.pocketmindserver.ai.application.stream.SseReplyService;
import com.doublez.pocketmindserver.ai.api.dto.chat.ChatBranchSummaryResponse;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.resource.application.ChatTranscriptResourceSyncService;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.http.HttpStatus;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import reactor.core.publisher.Flux;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * AI 对话服务层?
 * 负责：组装上下文（历史消?+ 笔记摘要 + 图片描述）→ 流式调用 AI 持久化消息
 */
@Slf4j
@Service
public class AiChatService {

    private final ChatSessionRepository chatSessionRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final ContextAssembler contextAssembler;
    private final SseReplyService sseReplyService;
    private final ChatTranscriptResourceSyncService chatTranscriptResourceSyncService;

    public AiChatService(
            ChatSessionRepository chatSessionRepository,
            ChatMessageRepository chatMessageRepository,
            ContextAssembler contextAssembler,
            SseReplyService sseReplyService,
            ChatTranscriptResourceSyncService chatTranscriptResourceSyncService) {
        this.chatSessionRepository = chatSessionRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.contextAssembler = contextAssembler;
        this.sseReplyService = sseReplyService;
        this.chatTranscriptResourceSyncService = chatTranscriptResourceSyncService;
    }

    
    // 会话管理
    

    /**
     * 创建会话（全屢对话或关联某篇笔记）?
     */
    public ChatSessionEntity createSession(long userId, UUID noteUuid, String title) {
        UUID sessionUuid = UUID.randomUUID();
        String finalTitle = (title == null || title.isBlank()) ? "新对话" : title;
        ChatSessionEntity session = ChatSessionEntity.create(
            sessionUuid, userId, noteUuid, finalTitle);
        chatSessionRepository.save(session);
        chatTranscriptResourceSyncService.syncSessionTranscript(userId, sessionUuid);
        log.info("创建会话: userId={}, sessionUuid={}, noteUuid={}", userId, sessionUuid, noteUuid);
        return session;
    }

    /**
     * 列出当前用户的会话列表，可按笔记过滤?
     */
    public List<ChatSessionEntity> listSessions(long userId, UUID noteUuid, PageQuery pageQuery) {
        return noteUuid != null
                ? chatSessionRepository.findByNoteUuid(userId, noteUuid)
                : chatSessionRepository.findByUserId(userId, pageQuery);
    }

    /**
     * 查询单个会话详情?
     */
    public ChatSessionEntity getSession(long userId, UUID sessionUuid) {
        return validateAndGetSession(sessionUuid, userId);
    }

    /**
     * 重命名会话标题?
     */
    public void renameSession(long userId, UUID sessionUuid, String title) {
        ChatSessionEntity session = validateAndGetSession(sessionUuid, userId);
        session.updateTitle(title != null ? title : "");
        chatSessionRepository.update(session);
        log.info("重命名会? userId={}, sessionUuid={}, title={}", userId, sessionUuid, title);
    }

    /**
     * 软删除会话?
     */
    public void deleteSession(long userId, UUID sessionUuid) {
        validateAndGetSession(sessionUuid, userId);
        chatSessionRepository.deleteByUuidAndUserId(sessionUuid, userId);
        chatTranscriptResourceSyncService.softDeleteBySession(userId, sessionUuid);
        log.info("删除会话: userId={}, sessionUuid={}", userId, sessionUuid);
    }

    /**
     * 列出会话下的消息列表?
     * 若传?leafUuid，则返回从叶节点到链头的完整分支消息链（用于分支模式）?
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
     * 接收用户消息，流式返?AI 回答?
     * @param parentUuid 可非 null 时从该节点创建新分支（链式消息历史从此节点溯源）?
     *                   null 时线性追加到当前会话末尾?
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
            // 分支模式：从指定节点向上递归获取完整历史?
            history = chatMessageRepository.findChain(parentUuid, userId);
            effectiveParentUuid = parentUuid;
        } else {
            // 线模式：取会话全部消息（朢?200 条）
            history = chatMessageRepository.findBySessionUuid(userId, sessionUuid, new PageQuery(200, 0));
            effectiveParentUuid = history.isEmpty() ? null : history.get(history.size() - 1).getUuid();
        }

        // 3. 构建 system prompt（含笔记上下?+ 图片识别内容?
        String systemText = contextAssembler.buildSystemPrompt(userId, session, userPrompt);

        // 4. 持久化用户消息（同步落库?
        UUID userMsgUuid = UUID.randomUUID();
        ChatMessageEntity userMsg = ChatMessageEntity.create(
                userMsgUuid, userId, sessionUuid, effectiveParentUuid,
                ChatRole.USER, userPrompt, attachmentUuids);
        chatMessageRepository.save(userMsg);
        chatTranscriptResourceSyncService.syncSessionTranscript(userId, sessionUuid);

        // 5. 棢测分叉：?parentUuid 非空，则本次是显式分岔操?
        final boolean isFork = (parentUuid != null);

        // 6. 构建 Spring AI 历史消息列表
        List<Message> historyMessages = toSpringAiMessages(history);

        // 7. 流式调用 AI
        return sseReplyService.streamReply(userId, sessionUuid, userMsgUuid,
            userPrompt, systemText, historyMessages, isFork, requestId);
    }

    /**
     * streamReply 的无 parentUuid 重载（保持向后兼容）?
     */
    public Flux<ServerSentEvent<String>> streamReply(long userId,
                                                      UUID sessionUuid,
                                                      String userPrompt,
                                                      List<UUID> attachmentUuids) {
        return streamReply(userId, sessionUuid, userPrompt, attachmentUuids, null, UUID.randomUUID().toString());
    }

    
    // 缂栬緫銆佸垹闄ゃ€侀噸鏂扮敓鎴?
    

    /**
     * 编辑 USER 消息并删除紧随其后的 ASSISTANT 消息?
     * 浣跨敤涓ゆ SQL 瀹屾垚锛歶pdateContent锛堝惈闅愬紡 USER 瑙掕壊鏍￠獙锛夈€乻oftDeleteAssistantChildren銆?
     * 调用方（Controller）收到请求后，应随即触发丢?streamReply 以重新生?AI 回复?
     */
    @Transactional(rollbackFor = Exception.class)
    public void editUserMessage(long userId, UUID messageUuid, String newContent) {
        // 校验：仅允许编辑当前分支末尾?USER 消息，防止孤立下游对话链
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
        // updateContent 鐨?WHERE role = 'USER' 璧峰埌闅愬紡瑙掕壊鏍￠獙浣滅敤
        chatMessageRepository.updateContent(messageUuid, userId, newContent);
        // 单次 SQL 清理?USER 消息的所?ASSISTANT 子消?
        chatMessageRepository.softDeleteAssistantChildren(messageUuid, userId);
        ChatMessageEntity edited = chatMessageRepository.findByUuidAndUserId(messageUuid, userId).orElse(null);
        if (edited != null) {
            chatTranscriptResourceSyncService.syncSessionTranscript(userId, edited.getSessionUuid());
        }
        log.info("编辑用户消息: userId={}, messageUuid={}", userId, messageUuid);
    }

    /**
     * 重新生成 AI 回复（SSE 流式）统丢入口，按消息角色分派?
     * <ul>
     *   <li>传入 USER UUID（editAndResend 场景）：ASSISTANT 已由 editUserMessage 清除?
     *       直接复用?USER 消息流式生成?ASSISTANT 回复?/li>
     *   <li>传入 ASSISTANT UUID（标准重新生成）：先软删除目?ASSISTANT?
     *       再以其父 USER 消息重新调用 AI?/li>
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
            // editAndResend 场景：ASSISTANT 已由 editUserMessage 软删除，直接复用?USER 消息
            userMsg = msg;
            log.info("editAndResend 继续生成: userId={}, sessionUuid={}, userMsgUuid={}", userId, sessionUuid, messageUuid);
        } else if (msg.getRole() == ChatRole.ASSISTANT) {
            // 标准重新生成：软删除?ASSISTANT，找到父 USER
            UUID userMsgUuid = msg.getParentUuid();
            if (userMsgUuid == null) {
                throw new BusinessException(ApiCode.REQ_VALIDATION, HttpStatus.BAD_REQUEST,
                        "ASSISTANT 消息没有关联?USER 消息");
            }
            chatMessageRepository.softDeleteByUuids(List.of(messageUuid), userId);
                chatTranscriptResourceSyncService.syncSessionTranscript(userId, sessionUuid);
            userMsg = chatMessageRepository.findByUuidAndUserId(userMsgUuid, userId)
                    .orElseThrow(() -> new BusinessException(
                            ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "userMsgUuid=" + userMsgUuid));
            log.info("閲嶆柊鐢熸垚 AI 鍥炲: userId={}, sessionUuid={}, userMsgUuid={}", userId, sessionUuid, userMsgUuid);
        } else {
            throw new BusinessException(ApiCode.REQ_VALIDATION, HttpStatus.BAD_REQUEST,
                    "仅支持对 USER ?ASSISTANT 消息操作");
        }

        // 重建历史：从用户消息的父节点向上溯源，不含刚删的 ASSISTANT
        List<ChatMessageEntity> history = userMsg.getParentUuid() != null
                ? chatMessageRepository.findChain(userMsg.getParentUuid(), userId)
                : List.of();

        String systemText = contextAssembler.buildSystemPrompt(userId, session, userMsg.getContent());
        List<Message> historyMessages = toSpringAiMessages(history);

        return sseReplyService.streamReply(userId, sessionUuid, userMsg.getUuid(),
            userMsg.getContent(), systemText, historyMessages, false, requestId);
    }

    /**
     * 鍋滄鎸囧畾 requestId 鐨勬祦寮忓洖澶嶃€?
     */
    public void stopReply(long userId, UUID sessionUuid, String requestId) {
        validateAndGetSession(sessionUuid, userId);
        sseReplyService.stopReply(userId, sessionUuid, requestId);
    }

    
    // 评分
    

    /**
     * 对消息评分（点赞/点踩/取消）?
     * @param rating 1=点赞?=取消?1=点踩
     */
    public void rateMessage(long userId, UUID messageUuid, int rating) {
        chatMessageRepository.findByUuidAndUserId(messageUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "messageUuid=" + messageUuid));
        chatMessageRepository.updateRating(messageUuid, userId, rating);
        log.info("消息评分: userId={}, messageUuid={}, rating={}", userId, messageUuid, rating);
    }

    /**
     * 更新分支别名（用户手动编辑）?
     * 闀垮害闄愬埗鐢辫皟鐢ㄦ柟锛圕ontroller @Valid锛夋牎楠屻€?
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
     * 获取当前会话的全部分支摘要?
     * 策略：找到所?有多个子节点的父节点"（分叉点），对每个分叉点的子节点
     * 分别沿链追溯到最新的叶节点，提取朢后一?USER+ASSISTANT 内容?
     * 前端通过 leafUuid 参数请求完整链消息?
     */
    public List<ChatBranchSummaryResponse> getBranches(long userId, UUID sessionUuid) {
        // 加载会话全量消息（用于分析分叉结构）
        List<ChatMessageEntity> allMessages = chatMessageRepository.findBySessionUuid(
                userId, sessionUuid, PageQuery.unbounded(1000));
        if (allMessages.isEmpty()) return List.of();

        List<ChatMessageEntity> leaves = findLeafMessages(allMessages);

        // 若只有一个叶节点，则没有分支
        if (leaves.size() <= 1) return List.of();

        // 涓烘瘡涓彾鑺傜偣鐢熸垚鎽樿
        return leaves.stream()
                .map(leaf -> buildBranchSummary(leaf, allMessages))
                .filter(Objects::nonNull)
                .sorted(java.util.Comparator.comparing(ChatBranchSummaryResponse::updatedAt).reversed())
                .toList();
    }

    
    // 私有核心方法
    

    /**
     * 为单个叶节点构建分支摘要?
     */
    private ChatBranchSummaryResponse buildBranchSummary(ChatMessageEntity leaf,
                                                          List<ChatMessageEntity> allMessages) {
        // 娌?parentUuid 閾惧悜涓婃壘鏈€杩戜竴杞?USER+ASSISTANT
        String lastUserContent = null;
        String lastAssistantContent = null;
        UUID cursor = leaf.getUuid();

        // 鏋勫缓蹇€熸煡鎵?map
        java.util.Map<UUID, ChatMessageEntity> msgMap = new java.util.HashMap<>();
        for (ChatMessageEntity m : allMessages) {
            msgMap.put(m.getUuid(), m);
        }

        // 向上遍历链，找最近的 ASSISTANT ?USER
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
     * 获取会话主链消息?
     *
     * 规则：当未指?leafUuid 时，取最后创建的叶子节点”作为当前主链叶子，
     * 并返回该叶子的完整链路，避免把多分支全量混在丢起返回给前端?
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
     * 浠庡叏閲忔秷鎭腑鎵惧嚭鎵€鏈夊彾瀛愯妭鐐癸紙鏃犲瓙鑺傜偣锛夈€?
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
     * 校验会话归属权，不过则抛?404 异常?
     */
    private ChatSessionEntity validateAndGetSession(UUID sessionUuid, long userId) {
        return chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "sessionUuid=" + sessionUuid));
    }

    
    // 私有辅助方法
    

    /**
     * 将领域消息列表转换为 Spring AI Message 对象列表?
     * 仅转?TEXT 类型?USER/ASSISTANT 消息，跳过工具调用消息?
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

}

