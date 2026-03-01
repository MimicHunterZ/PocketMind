package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.ai.config.AiFailoverRouter;
import com.doublez.pocketmindserver.ai.api.dto.chat.ChatBranchSummaryResponse;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionEntity;
import com.doublez.pocketmindserver.attachment.domain.vision.AttachmentVisionRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.message.ChatRole;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.util.PromptBuilder;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
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
 * AI 瀵硅瘽娴佸紡搴旂敤鏈嶅姟銆?
 * 璐熻矗锛氱粍瑁呬笂涓嬫枃锛堝巻鍙叉秷鎭?+ 绗旇鎽樿 + 鍥剧墖鎻忚堪锛夆啋 娴佸紡璋冪敤 AI 鈫?鎸佷箙鍖栨秷鎭€?
 */
@Slf4j
@Service
public class AiChatService {

    private final AiFailoverRouter aiFailoverRouter;
    private final ChatSessionRepository chatSessionRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final NoteRepository noteRepository;
    private final AttachmentVisionRepository attachmentVisionRepository;
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
            AttachmentVisionRepository attachmentVisionRepository,
            ChatStreamCancellationManager chatStreamCancellationManager,
            ChatSseEventFactory chatSseEventFactory) {
        this.aiFailoverRouter = aiFailoverRouter;
        this.chatSessionRepository = chatSessionRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.noteRepository = noteRepository;
        this.attachmentVisionRepository = attachmentVisionRepository;
        this.chatStreamCancellationManager = chatStreamCancellationManager;
        this.chatSseEventFactory = chatSseEventFactory;
    }

    
    // 浼氳瘽绠＄悊
    

    /**
     * 鍒涘缓浼氳瘽锛堝叏灞€瀵硅瘽鎴栧叧鑱旀煇绡囩瑪璁帮級銆?
     */
    public ChatSessionEntity createSession(long userId, UUID noteUuid, String title) {
        UUID sessionUuid = UUID.randomUUID();
        String finalTitle = (title == null || title.isBlank()) ? "新对话" : title;
        ChatSessionEntity session = ChatSessionEntity.create(
            sessionUuid, userId, noteUuid, finalTitle);
        chatSessionRepository.save(session);
        log.info("鍒涘缓浼氳瘽: userId={}, sessionUuid={}, noteUuid={}", userId, sessionUuid, noteUuid);
        return session;
    }

    /**
     * 鍒楀嚭褰撳墠鐢ㄦ埛鐨勪細璇濆垪琛紝鍙寜绗旇杩囨护銆?
     */
    public List<ChatSessionEntity> listSessions(long userId, UUID noteUuid, PageQuery pageQuery) {
        return noteUuid != null
                ? chatSessionRepository.findByNoteUuid(userId, noteUuid)
                : chatSessionRepository.findByUserId(userId, pageQuery);
    }

    /**
     * 鏌ヨ鍗曚釜浼氳瘽璇︽儏銆?
     */
    public ChatSessionEntity getSession(long userId, UUID sessionUuid) {
        return validateAndGetSession(sessionUuid, userId);
    }

    /**
     * 閲嶅懡鍚嶄細璇濇爣棰樸€?
     */
    public void renameSession(long userId, UUID sessionUuid, String title) {
        ChatSessionEntity session = validateAndGetSession(sessionUuid, userId);
        session.updateTitle(title != null ? title : "");
        chatSessionRepository.update(session);
        log.info("閲嶅懡鍚嶄細璇? userId={}, sessionUuid={}, title={}", userId, sessionUuid, title);
    }

    /**
     * 杞垹闄や細璇濄€?
     */
    public void deleteSession(long userId, UUID sessionUuid) {
        validateAndGetSession(sessionUuid, userId);
        chatSessionRepository.deleteByUuidAndUserId(sessionUuid, userId);
        log.info("鍒犻櫎浼氳瘽: userId={}, sessionUuid={}", userId, sessionUuid);
    }

    /**
     * 鍒楀嚭浼氳瘽涓嬬殑娑堟伅鍒楄〃銆?
     * 鑻ヤ紶鍏?leafUuid锛屽垯杩斿洖浠庡彾鑺傜偣鍒伴摼澶寸殑瀹屾暣鍒嗘敮娑堟伅閾撅紙鐢ㄤ簬鍒嗘敮妯″紡锛夈€?
     */
    public List<ChatMessageEntity> listMessages(long userId, UUID sessionUuid, UUID leafUuid) {
        validateAndGetSession(sessionUuid, userId);
        if (leafUuid != null) {
            return chatMessageRepository.findChain(leafUuid, userId);
        }
        return listMainlineMessages(userId, sessionUuid);
    }

    
    // 娴佸紡鍥炲锛堝叆鍙ｏ級
    

    /**
     * 鎺ユ敹鐢ㄦ埛娑堟伅锛屾祦寮忚繑鍥?AI 鍥炵瓟銆?
     * @param parentUuid 鍙€夈€傞潪 null 鏃朵粠璇ヨ妭鐐瑰垱寤烘柊鍒嗘敮锛堥摼寮忔秷鎭巻鍙蹭粠姝よ妭鐐规函婧愶級銆?
     *                   null 鏃剁嚎鎬ц拷鍔犲埌褰撳墠浼氳瘽鏈熬銆?
     */
    public Flux<ServerSentEvent<String>> streamReply(long userId,
                                                      UUID sessionUuid,
                                                      String userPrompt,
                                                      List<UUID> attachmentUuids,
                                                      UUID parentUuid,
                                                      String requestId) {
        // 1. 鏍￠獙 session 褰掑睘
        ChatSessionEntity session = validateAndGetSession(sessionUuid, userId);

        // 2. 鍔犺浇鍘嗗彶娑堟伅
        final List<ChatMessageEntity> history;
        final UUID effectiveParentUuid;
        if (parentUuid != null) {
            // 鍒嗘敮妯″紡锛氫粠鎸囧畾鑺傜偣鍚戜笂閫掑綊鑾峰彇瀹屾暣鍘嗗彶閾?
            history = chatMessageRepository.findChain(parentUuid, userId);
            effectiveParentUuid = parentUuid;
        } else {
            // 绾挎€фā寮忥細鍙栦細璇濆叏閮ㄦ秷鎭紙鏈€澶?200 鏉★級
            history = chatMessageRepository.findBySessionUuid(userId, sessionUuid, new PageQuery(200, 0));
            effectiveParentUuid = history.isEmpty() ? null : history.get(history.size() - 1).getUuid();
        }

        // 3. 鏋勫缓 system prompt锛堝惈绗旇涓婁笅鏂?+ 鍥剧墖璇嗗埆鍐呭锛?
        String systemText = buildSystemPrompt(userId, session);

        // 4. 鎸佷箙鍖栫敤鎴锋秷鎭紙鍚屾钀藉簱锛?
        UUID userMsgUuid = UUID.randomUUID();
        ChatMessageEntity userMsg = ChatMessageEntity.create(
                userMsgUuid, userId, sessionUuid, effectiveParentUuid,
                ChatRole.USER, userPrompt, attachmentUuids);
        chatMessageRepository.save(userMsg);

        // 5. 妫€娴嬪垎鍙夛細鑻?parentUuid 闈炵┖锛屽垯鏈鏄樉寮忓垎宀旀搷浣?
        final boolean isFork = (parentUuid != null);

        // 6. 鏋勫缓 Spring AI 鍘嗗彶娑堟伅鍒楄〃
        List<Message> historyMessages = toSpringAiMessages(history);

        // 7. 娴佸紡璋冪敤 AI
        return buildAndStream(userId, sessionUuid, userMsgUuid,
            userPrompt, systemText, historyMessages, isFork, requestId);
    }

    /**
     * streamReply 鐨勬棤 parentUuid 閲嶈浇锛堜繚鎸佸悜鍚庡吋瀹癸級銆?
     */
    public Flux<ServerSentEvent<String>> streamReply(long userId,
                                                      UUID sessionUuid,
                                                      String userPrompt,
                                                      List<UUID> attachmentUuids) {
        return streamReply(userId, sessionUuid, userPrompt, attachmentUuids, null, UUID.randomUUID().toString());
    }

    
    // 缂栬緫銆佸垹闄ゃ€侀噸鏂扮敓鎴?
    

    /**
     * 缂栬緫 USER 娑堟伅骞跺垹闄ょ揣闅忓叾鍚庣殑 ASSISTANT 娑堟伅銆?
     * 浣跨敤涓ゆ SQL 瀹屾垚锛歶pdateContent锛堝惈闅愬紡 USER 瑙掕壊鏍￠獙锛夈€乻oftDeleteAssistantChildren銆?
     * 璋冪敤鏂癸紙Controller锛夋敹鍒拌姹傚悗锛屽簲闅忓嵆瑙﹀彂涓€娆?streamReply 浠ラ噸鏂扮敓鎴?AI 鍥炲銆?
     */
    @Transactional(rollbackFor = Exception.class)
    public void editUserMessage(long userId, UUID messageUuid, String newContent) {
        // 鏍￠獙锛氫粎鍏佽缂栬緫褰撳墠鍒嗘敮鏈熬鐨?USER 娑堟伅锛岄槻姝㈠绔嬩笅娓稿璇濋摼
        List<ChatMessageEntity> assistantChildren =
                chatMessageRepository.findChildrenByParentUuid(messageUuid, userId);
        for (ChatMessageEntity assistant : assistantChildren) {
            List<ChatMessageEntity> userGrandchildren =
                    chatMessageRepository.findChildrenByParentUuid(assistant.getUuid(), userId);
            if (!userGrandchildren.isEmpty()) {
                throw new BusinessException(ApiCode.REQ_VALIDATION, HttpStatus.UNPROCESSABLE_ENTITY,
                        "浠呭厑璁哥紪杈戝綋鍓嶅垎鏀湯灏剧殑鐢ㄦ埛娑堟伅锛岃鍏堝垏鎹㈠埌鐩爣鍒嗘敮");
            }
        }
        // updateContent 鐨?WHERE role = 'USER' 璧峰埌闅愬紡瑙掕壊鏍￠獙浣滅敤
        chatMessageRepository.updateContent(messageUuid, userId, newContent);
        // 鍗曟 SQL 娓呯悊璇?USER 娑堟伅鐨勬墍鏈?ASSISTANT 瀛愭秷鎭?
        chatMessageRepository.softDeleteAssistantChildren(messageUuid, userId);
        log.info("缂栬緫鐢ㄦ埛娑堟伅: userId={}, messageUuid={}", userId, messageUuid);
    }

    /**
     * 閲嶆柊鐢熸垚 AI 鍥炲锛圫SE 娴佸紡锛夈€傜粺涓€鍏ュ彛锛屾寜娑堟伅瑙掕壊鍒嗘淳锛?
     * <ul>
     *   <li>浼犲叆 USER UUID锛坋ditAndResend 鍦烘櫙锛夛細ASSISTANT 宸茬敱 editUserMessage 娓呴櫎锛?
     *       鐩存帴澶嶇敤璇?USER 娑堟伅娴佸紡鐢熸垚鏂?ASSISTANT 鍥炲銆?/li>
     *   <li>浼犲叆 ASSISTANT UUID锛堟爣鍑嗛噸鏂扮敓鎴愶級锛氬厛杞垹闄ょ洰鏍?ASSISTANT锛?
     *       鍐嶄互鍏剁埗 USER 娑堟伅閲嶆柊璋冪敤 AI銆?/li>
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
            // editAndResend 鍦烘櫙锛欰SSISTANT 宸茬敱 editUserMessage 杞垹闄わ紝鐩存帴澶嶇敤璇?USER 娑堟伅
            userMsg = msg;
            log.info("editAndResend 缁х画鐢熸垚: userId={}, sessionUuid={}, userMsgUuid={}", userId, sessionUuid, messageUuid);
        } else if (msg.getRole() == ChatRole.ASSISTANT) {
            // 鏍囧噯閲嶆柊鐢熸垚锛氳蒋鍒犻櫎鏃?ASSISTANT锛屾壘鍒扮埗 USER
            UUID userMsgUuid = msg.getParentUuid();
            if (userMsgUuid == null) {
                throw new BusinessException(ApiCode.REQ_VALIDATION, HttpStatus.BAD_REQUEST,
                        "ASSISTANT 娑堟伅娌℃湁鍏宠仈鐨?USER 娑堟伅");
            }
            chatMessageRepository.softDeleteByUuids(List.of(messageUuid), userId);
            userMsg = chatMessageRepository.findByUuidAndUserId(userMsgUuid, userId)
                    .orElseThrow(() -> new BusinessException(
                            ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "userMsgUuid=" + userMsgUuid));
            log.info("閲嶆柊鐢熸垚 AI 鍥炲: userId={}, sessionUuid={}, userMsgUuid={}", userId, sessionUuid, userMsgUuid);
        } else {
            throw new BusinessException(ApiCode.REQ_VALIDATION, HttpStatus.BAD_REQUEST,
                    "浠呮敮鎸佸 USER 鎴?ASSISTANT 娑堟伅鎿嶄綔");
        }

        // 閲嶅缓鍘嗗彶锛氫粠鐢ㄦ埛娑堟伅鐨勭埗鑺傜偣鍚戜笂婧簮锛屼笉鍚垰鍒犵殑 ASSISTANT
        List<ChatMessageEntity> history = userMsg.getParentUuid() != null
                ? chatMessageRepository.findChain(userMsg.getParentUuid(), userId)
                : List.of();

        String systemText = buildSystemPrompt(userId, session);
        List<Message> historyMessages = toSpringAiMessages(history);

        return buildAndStream(userId, sessionUuid, userMsg.getUuid(),
            userMsg.getContent(), systemText, historyMessages, false, requestId);
    }

    /**
     * 鍋滄鎸囧畾 requestId 鐨勬祦寮忓洖澶嶃€?
     */
    public void stopReply(long userId, UUID sessionUuid, String requestId) {
        validateAndGetSession(sessionUuid, userId);
        String streamKey = chatStreamCancellationManager.buildKey(userId, sessionUuid, requestId);
        boolean cancelled = chatStreamCancellationManager.cancel(streamKey, "user_stop");
        if (cancelled) {
            log.info("鍋滄娴佸紡鍥炲: userId={}, sessionUuid={}, requestId={}", userId, sessionUuid, requestId);
        } else {
            log.info("鍋滄娴佸紡鍥炲璇锋眰鏈懡涓椿鍔ㄦ祦: userId={}, sessionUuid={}, requestId={}", userId, sessionUuid, requestId);
        }
    }

    
    // 璇勫垎
    

    /**
     * 瀵规秷鎭瘎鍒嗭紙鐐硅禐/鐐硅俯/鍙栨秷锛夈€?
     * @param rating 1=鐐硅禐锛?=鍙栨秷锛?1=鐐硅俯
     */
    public void rateMessage(long userId, UUID messageUuid, int rating) {
        chatMessageRepository.findByUuidAndUserId(messageUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "messageUuid=" + messageUuid));
        chatMessageRepository.updateRating(messageUuid, userId, rating);
        log.info("娑堟伅璇勫垎: userId={}, messageUuid={}, rating={}", userId, messageUuid, rating);
    }

    /**
     * 鏇存柊鍒嗘敮鍒悕锛堢敤鎴锋墜鍔ㄧ紪杈戯級銆?
     * 闀垮害闄愬埗鐢辫皟鐢ㄦ柟锛圕ontroller @Valid锛夋牎楠屻€?
     */
    public void updateBranchAlias(long userId, UUID messageUuid, String alias) {
        chatMessageRepository.findByUuidAndUserId(messageUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "messageUuid=" + messageUuid));
        chatMessageRepository.updateBranchAlias(messageUuid, userId, alias.trim());
        log.info("鏇存柊鍒嗘敮鍒悕: userId={}, messageUuid={}, alias={}", userId, messageUuid, alias);
    }

    
    // 鍒嗘敮绠＄悊
    

    /**
     * 鑾峰彇褰撳墠浼氳瘽鐨勫叏閮ㄥ垎鏀憳瑕併€?
     * 绛栫暐锛氭壘鍒版墍鏈?鏈夊涓瓙鑺傜偣鐨勭埗鑺傜偣"锛堝垎鍙夌偣锛夛紝瀵规瘡涓垎鍙夌偣鐨勫瓙鑺傜偣
     * 鍒嗗埆娌块摼杩芥函鍒版渶鏂扮殑鍙惰妭鐐癸紝鎻愬彇鏈€鍚庝竴杞?USER+ASSISTANT 鍐呭銆?
     * 鍓嶇閫氳繃 leafUuid 鍙傛暟璇锋眰瀹屾暣閾炬秷鎭€?
     */
    public List<ChatBranchSummaryResponse> getBranches(long userId, UUID sessionUuid) {
        // 鍔犺浇浼氳瘽鍏ㄩ噺娑堟伅锛堢敤浜庡垎鏋愬垎鍙夌粨鏋勶級
        List<ChatMessageEntity> allMessages = chatMessageRepository.findBySessionUuid(
                userId, sessionUuid, PageQuery.unbounded(1000));
        if (allMessages.isEmpty()) return List.of();

        List<ChatMessageEntity> leaves = findLeafMessages(allMessages);

        // 鑻ュ彧鏈変竴涓彾鑺傜偣锛屽垯娌℃湁鍒嗘敮
        if (leaves.size() <= 1) return List.of();

        // 涓烘瘡涓彾鑺傜偣鐢熸垚鎽樿
        return leaves.stream()
                .map(leaf -> buildBranchSummary(leaf, allMessages))
                .filter(Objects::nonNull)
                .sorted(java.util.Comparator.comparing(ChatBranchSummaryResponse::updatedAt).reversed())
                .toList();
    }

    
    // 绉佹湁鏍稿績鏂规硶
    

    /**
     * 娴佸紡璋冪敤 AI 骞惰惤搴?ASSISTANT 娑堟伅鐨勬牳蹇冮€昏緫銆?
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
                    log.info("妫€娴嬪埌娴佸紡鍥炲鍙栨秷淇″彿: userId={}, sessionUuid={}, requestId={}, reason={}",
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
                    log.error("AI 娴佸紡鍥炲寮傚父: userId={}, sessionUuid={}", userId, sessionUuid, e);
                    String safeMsg = e.getMessage() != null ? e.getMessage() : "AI 鏈嶅姟寮傚父";
                    return Flux.just(chatSseEventFactory.error(effectiveRequestId, safeMsg));
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
            log.info("AI 娴佸紡鍥炲鏆傚仠骞朵繚瀛橀儴鍒嗗唴瀹? userId={}, sessionUuid={}, assistantMsgUuid={}",
                    userId, sessionUuid, pausedMessageUuid);
        } else {
            log.info("AI 娴佸紡鍥炲鏆傚仠锛堟棤鍙繚瀛樺閲忥級: userId={}, sessionUuid={}", userId, sessionUuid);
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

        log.info("AI 娴佸紡鍥炲瀹屾垚: userId={}, sessionUuid={}, assistantMsgUuid={}",
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
     * 寮傛鐢熸垚鍒嗘敮鍒悕骞跺啓鍏ユ暟鎹簱銆?
     * 浣跨敤寤変环鐨勪竴娆℃€?LLM 璋冪敤锛屼紶鍏?1-2 杞璇濅笂涓嬫枃銆?
     */
    private void generateBranchAliasAsync(long userId,
                                           UUID assistantMsgUuid,
                                           UUID userMsgUuid,
                                           List<Message> historyMessages,
                                           String userPrompt) {
        Schedulers.boundedElastic().schedule(() -> {
            try {
                // 鍙栨渶杩?1 杞殑涓婁笅鏂囷細姝ゅ墠鍘嗗彶鏈熬 AI 鍥炲锛堝鏈夛級
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
                    // 鎴彇鍓?8 瀛楋紝鍘婚櫎绌虹櫧/鏍囩偣
                    alias = alias.replaceAll("[\\p{P}\\s]", "");
                    if (alias.length() > 10) alias = alias.substring(0, 10);
                    if (!alias.isBlank()) {
                        chatMessageRepository.updateBranchAlias(assistantMsgUuid, userId, alias);
                        log.info("鍒嗘敮鍒悕鐢熸垚: userId={}, messageUuid={}, alias={}", userId, assistantMsgUuid, alias);
                    }
                }
            } catch (Exception e) {
                log.warn("鍒嗘敮鍒悕鐢熸垚澶辫触锛堥潤榛樺拷鐣ワ級: userId={}, messageUuid={}, error={}", userId, assistantMsgUuid, e.getMessage());
            }
        });
    }

    /**
     * 涓哄崟涓彾鑺傜偣鏋勫缓鍒嗘敮鎽樿銆?
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

        // 鍚戜笂閬嶅巻閾撅紝鎵炬渶杩戠殑 ASSISTANT 鍜?USER
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
     * 鑾峰彇浼氳瘽涓婚摼娑堟伅銆?
     *
     * 瑙勫垯锛氬綋鏈寚瀹?leafUuid 鏃讹紝鍙栤€滄渶鍚庡垱寤虹殑鍙跺瓙鑺傜偣鈥濅綔涓哄綋鍓嶄富閾惧彾瀛愶紝
     * 骞惰繑鍥炶鍙跺瓙鐨勫畬鏁撮摼璺紝閬垮厤鎶婂鍒嗘敮鍏ㄩ噺娣峰湪涓€璧疯繑鍥炵粰鍓嶇銆?
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
     * 鏍￠獙浼氳瘽褰掑睘鏉冿紝涓嶉€氳繃鍒欐姏鍑?404 寮傚父銆?
     */
    private ChatSessionEntity validateAndGetSession(UUID sessionUuid, long userId) {
        return chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "sessionUuid=" + sessionUuid));
    }

    
    // 绉佹湁杈呭姪鏂规硶
    

    /**
     * 鏋勫缓 system prompt銆?
     * 鏈夌瑪璁颁笂涓嬫枃鏃舵覆鏌?prompts/chat/note_system.md锛屽惁鍒欏姞杞?prompts/chat/global_system.md銆?
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

            // 缁勮 noteContext 娈佃惤
            StringBuilder noteContext = new StringBuilder();

            if (hasText(note.getTitle())) {
                noteContext.append("**鏍囬**: ").append(note.getTitle()).append("\n\n");
            }
            if (hasText(note.getSummary())) {
                noteContext.append("**鎽樿**:\n").append(note.getSummary()).append("\n\n");
            }

            // 浼樺厛浣跨敤鐢ㄦ埛鎵嬪啓鍐呭锛屽叾娆′娇鐢ㄧ埇鍙栧唴瀹?
            String bodyContent = hasText(note.getContent())
                    ? note.getContent()
                    : note.getPreviewContent();
            if (hasText(bodyContent)) {
                noteContext.append("**姝ｆ枃**:\n").append(bodyContent).append("\n\n");
            }

            // 鍥剧墖璇嗗埆缁撴灉锛坰tatus=DONE锛?
            List<AttachmentVisionEntity> visions = attachmentVisionRepository
                    .findDoneByNoteUuid(userId, session.getScopeNoteUuid());
            List<String> imageTexts = visions.stream()
                    .map(AttachmentVisionEntity::getContent)
                    .filter(Objects::nonNull)
                    .filter(c -> !c.isBlank())
                    .toList();
            if (!imageTexts.isEmpty()) {
                noteContext.append("**鍥剧墖璇嗗埆鍐呭**:\n");
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
     * 灏嗛鍩熸秷鎭垪琛ㄨ浆鎹负 Spring AI Message 瀵硅薄鍒楄〃銆?
     * 浠呰浆鎹?TEXT 绫诲瀷鐨?USER/ASSISTANT 娑堟伅锛岃烦杩囧伐鍏疯皟鐢ㄦ秷鎭€?
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

