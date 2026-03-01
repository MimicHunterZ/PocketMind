package com.doublez.pocketmindserver.ai.api;

import com.doublez.pocketmindserver.ai.api.dto.chat.ChatBranchSummaryResponse;
import com.doublez.pocketmindserver.ai.api.dto.chat.ChatMessageResponse;
import com.doublez.pocketmindserver.ai.api.dto.chat.ChatMessageResponse.ToolCallData;
import com.doublez.pocketmindserver.ai.api.dto.chat.ChatSessionResponse;
import com.doublez.pocketmindserver.ai.api.dto.chat.CreateSessionRequest;
import com.doublez.pocketmindserver.ai.api.dto.chat.EditMessageRequest;
import com.doublez.pocketmindserver.ai.api.dto.chat.GenerateTitleRequest;
import com.doublez.pocketmindserver.ai.api.dto.chat.RateMessageRequest;
import com.doublez.pocketmindserver.ai.api.dto.chat.SendMessageRequest;
import com.doublez.pocketmindserver.ai.api.dto.chat.StopMessageRequest;
import com.doublez.pocketmindserver.ai.api.dto.chat.UpdateAliasRequest;
import com.doublez.pocketmindserver.ai.api.dto.chat.UpdateSessionRequest;
import com.doublez.pocketmindserver.ai.application.AiChatService;
import com.doublez.pocketmindserver.ai.application.AiChatTitleService;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Flux;

import java.util.List;
import java.util.UUID;

/**
 * 鑱婂ぉ浼氳瘽 & 娑堟伅鎺ュ彛銆?
 *
 * <pre>
 * POST   /api/ai/sessions                            鍒涘缓浼氳瘽
 * GET    /api/ai/sessions[?noteUuid=&page=&size=]    鍒楀嚭浼氳瘽
 * GET    /api/ai/sessions/{uuid}/messages            鍒楀嚭娑堟伅
 * POST   /api/ai/sessions/{uuid}/messages            鍙戦€佹秷鎭紙SSE 娴佸紡杩斿洖锛?
 * PATCH  /api/ai/sessions/{uuid}                     閲嶅懡鍚嶄細璇?
 * DELETE /api/ai/sessions/{uuid}                     杞垹闄や細璇?
 * </pre>
 */
@Slf4j
@RestController
@RequestMapping("/api/ai/sessions")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class ChatController {

    private final AiChatService aiChatService;
    private final AiChatTitleService aiChatTitleService;
    private final ObjectMapper objectMapper;

    // 浼氳瘽绠＄悊

    /**
     * 鍒涘缓浼氳瘽锛堝叏灞€瀵硅瘽鎴栧叧鑱旀煇绡囩瑪璁帮級銆?
     */
    @PostMapping
    public ResponseEntity<ChatSessionResponse> createSession(
            @Valid @RequestBody CreateSessionRequest request) {
        long userId = parseUserId();
        ChatSessionEntity session = aiChatService.createSession(
                userId, request.noteUuid(), request.title());
        return ResponseEntity.status(HttpStatus.CREATED).body(toSessionResponse(session));
    }

    /**
     * 鍒楀嚭褰撳墠鐢ㄦ埛鐨勪細璇濓紝鍙寜绗旇杩囨护銆?
     *
     * @param noteUuid 鍏宠仈绗旇 UUID锛堝彲閫夛級
     * @param page     椤电爜锛堜粠 0 寮€濮嬶紝榛樿 0锛?
     * @param size     姣忛〉鏉℃暟锛堥粯璁?50锛?
     */
    @GetMapping
    public List<ChatSessionResponse> listSessions(
            @RequestParam(required = false) UUID noteUuid,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        long userId = parseUserId();
        return aiChatService.listSessions(userId, noteUuid, PageQuery.of(size, page))
                .stream().map(this::toSessionResponse).toList();
    }

    /**
     * 鑾峰彇鍗曚釜浼氳瘽璇︽儏銆?
     */
    @GetMapping("/{sessionUuid}")
    public ChatSessionResponse getSession(@PathVariable UUID sessionUuid) {
        long userId = parseUserId();
        return toSessionResponse(aiChatService.getSession(userId, sessionUuid));
    }

    /**
     * 閲嶅懡鍚嶄細璇濇爣棰樸€?
     */
    @PatchMapping("/{sessionUuid}")
    public void renameSession(
            @PathVariable UUID sessionUuid,
            @Valid @RequestBody UpdateSessionRequest request) {
        long userId = parseUserId();
        aiChatService.renameSession(userId, sessionUuid, request.title());
    }

    /**
     * 杞垹闄や細璇濄€?
     */
    @DeleteMapping("/{sessionUuid}")
    public void deleteSession(@PathVariable UUID sessionUuid) {
        long userId = parseUserId();
        aiChatService.deleteSession(userId, sessionUuid);
    }

    // 娑堟伅绠＄悊

    /**
     * 鍒楀嚭浼氳瘽涓嬬殑鎵€鏈夋秷鎭紙鎸夋椂闂存搴忥紝鏈€澶?500 鏉★級銆?
     * 鑻ヤ紶鍏?leafUuid锛屽垯杩斿洖浠庡彾鑺傜偣鍒伴摼澶寸殑瀹屾暣鍒嗘敮娑堟伅閾撅紙鐢ㄤ簬鍒嗘敮妯″紡锛夈€?
     */
    @GetMapping("/{sessionUuid}/messages")
    public List<ChatMessageResponse> listMessages(
            @PathVariable UUID sessionUuid,
            @RequestParam(required = false) UUID leafUuid) {
        long userId = parseUserId();
        return aiChatService.listMessages(userId, sessionUuid, leafUuid)
                .stream().map(this::toMessageResponse).toList();
    }

    /**
     * 鍙戦€佺敤鎴锋秷鎭苟娴佸紡鎺ユ敹 AI 鍥炲锛圫SE锛夈€?
     *
     * <p>SSE 浜嬩欢鏍煎紡锛?
     * <pre>
     *   event: delta
     *   data: <鏂囧瓧鐗囨>
    *
     *   event: done
    *   data: {"messageUuid":"<uuid>"}
     *
     *   event: error
     *   data: {"message":"<閿欒淇℃伅>"}
     * </pre>
     */
    @PostMapping(
            value = "/{sessionUuid}/messages",
            produces = MediaType.TEXT_EVENT_STREAM_VALUE
    )
    public Flux<ServerSentEvent<String>> sendMessage(
            @PathVariable UUID sessionUuid,
            @RequestHeader(name = "X-Request-Id", required = false) String requestId,
            @Valid @RequestBody SendMessageRequest request) {
        long userId = parseUserId();
        String effectiveRequestId = requestId != null && !requestId.isBlank()
            ? requestId
            : UUID.randomUUID().toString();

        log.info("鏀跺埌瀵硅瘽娑堟伅: userId={}, sessionUuid={}, contentLen={}",
                userId, sessionUuid, request.content().length());

        Flux<ServerSentEvent<String>> tokenFlux = aiChatService.streamReply(
                userId,
                sessionUuid,
                request.content(),
                request.safeAttachmentUuids(),
            request.parentUuid(),
            effectiveRequestId);
        return tokenFlux;
    }

    /**
     * 鍗曠嫭鐢熸垚骞舵洿鏂颁細璇濇爣棰樸€?
     */
    @PostMapping("/{sessionUuid}/title")
    public ChatSessionResponse generateSessionTitle(
            @PathVariable UUID sessionUuid,
            @Valid @RequestBody GenerateTitleRequest request) {
        long userId = parseUserId();
        aiChatTitleService.generateAndUpdateTitle(userId, sessionUuid, request.content());
        return toSessionResponse(aiChatService.getSession(userId, sessionUuid));
    }

    /**
     * 缂栬緫 USER 娑堟伅鍐呭锛堝悓鏃跺垹闄ょ揣闅忓叾鍚庣殑 ASSISTANT 娑堟伅锛岀瓑寰呭鎴风瑙﹀彂閲嶆柊鐢熸垚锛夈€?
     */
    @PatchMapping("/{sessionUuid}/messages/{messageUuid}")
    public void editMessage(
            @PathVariable UUID sessionUuid,
            @PathVariable UUID messageUuid,
            @Valid @RequestBody EditMessageRequest request) {
        long userId = parseUserId();
        aiChatService.editUserMessage(userId, messageUuid, request.content());
        log.info("缂栬緫娑堟伅: userId={}, messageUuid={}", userId, messageUuid);
    }

    /**
     * 閲嶆柊鐢熸垚鎸囧畾娑堟伅鐨?AI 鍥炲锛圫SE 娴佸紡锛夈€?
     *
     * <p>鏀寔涓ょ璋冪敤鏂瑰紡锛?
     * <ul>
     *   <li>ASSISTANT UUID锛氭爣鍑嗛噸鏂扮敓鎴愶紝杞垹闄ゆ棫鍥炲鍚庨噸鏂拌皟鐢?AI銆?/li>
     *   <li>USER UUID锛氱户缁敓鎴愶紝閫傜敤浜?editAndResend 鍦烘櫙锛圓SSISTANT 宸茶 editMessage 娓呴櫎锛夈€?/li>
     * </ul>
     */
    @PostMapping(
            value = "/{sessionUuid}/messages/{messageUuid}/regenerate",
            produces = MediaType.TEXT_EVENT_STREAM_VALUE
    )
    public Flux<ServerSentEvent<String>> regenerateMessage(
            @PathVariable UUID sessionUuid,
            @RequestHeader(name = "X-Request-Id", required = false) String requestId,
            @PathVariable UUID messageUuid) {
        long userId = parseUserId();
        String effectiveRequestId = requestId != null && !requestId.isBlank()
                ? requestId
                : UUID.randomUUID().toString();
        log.info("閲嶆柊鐢熸垚娑堟伅: userId={}, sessionUuid={}, messageUuid={}", userId, sessionUuid, messageUuid);
        return aiChatService.regenerateReply(userId, sessionUuid, messageUuid, effectiveRequestId);
    }

    /**
     * 鍋滄鎸囧畾 requestId 鐨勬祦寮忓洖澶嶃€?
     */
    @PostMapping("/{sessionUuid}/messages/stop")
    public void stopMessage(
            @PathVariable UUID sessionUuid,
            @Valid @RequestBody StopMessageRequest request) {
        long userId = parseUserId();
        aiChatService.stopReply(userId, sessionUuid, request.requestId());
    }

    /**
     * 瀵规秷鎭瘎鍒嗭紙鐐硅禐/鐐硅俯/鍙栨秷锛夈€?
     */
    @PostMapping("/{sessionUuid}/messages/{messageUuid}/rating")
    public void rateMessage(
            @PathVariable UUID sessionUuid,
            @PathVariable UUID messageUuid,
            @Valid @RequestBody RateMessageRequest request) {
        long userId = parseUserId();
        aiChatService.rateMessage(userId, messageUuid, request.rating());
    }

    /**
     * 鏇存柊鍒嗘敮鍒悕锛堢敤鎴锋墜鍔ㄧ紪杈戯紝鏈€澶?10 瀛楃锛夈€?
     */
    @PatchMapping("/{sessionUuid}/messages/{messageUuid}/alias")
    public void updateAlias(
            @PathVariable UUID sessionUuid,
            @PathVariable UUID messageUuid,
            @Valid @RequestBody UpdateAliasRequest request) {
        long userId = parseUserId();
        aiChatService.updateBranchAlias(userId, messageUuid, request.alias());
        log.info("鏇存柊鍒嗘敮鍒悕: userId={}, messageUuid={}", userId, messageUuid);
    }

    /**
     * 鑾峰彇浼氳瘽鐨勬墍鏈夊垎鏀憳瑕佸垪琛ㄣ€?
     */
    @GetMapping("/{sessionUuid}/branches")
    public List<ChatBranchSummaryResponse> getBranches(@PathVariable UUID sessionUuid) {
        long userId = parseUserId();
        return aiChatService.getBranches(userId, sessionUuid);
    }

    // 绉佹湁杞崲 & 宸ュ叿鏂规硶

    private ChatSessionResponse toSessionResponse(ChatSessionEntity s) {
        return new ChatSessionResponse(
                s.getUuid(),
                s.getScopeNoteUuid(),
                s.getTitle(),
                s.getUpdatedAt());
    }

    private ChatMessageResponse toMessageResponse(ChatMessageEntity m) {
        return new ChatMessageResponse(
                m.getUuid(),
                m.getSessionUuid(),
                m.getParentUuid(),
                m.getRole().name(),
                m.getMessageType(),
                m.getContent(),
                m.getAttachmentUuids(),
                m.getUpdatedAt(),
                parseToolCallData(m),
                m.getRating(),
                m.getBranchAlias());
    }

    /**
     * 瑙ｆ瀽宸ュ叿璋冪敤鍏冩暟鎹€?
     * TOOL_CALL 鍜?TOOL_RESULT 绫诲瀷鐨勬秷鎭?content 涓?JSON锛岃В鏋愪负缁撴瀯鍖栨暟鎹緵瀹㈡埛绔覆鏌?UI銆?
     */
    private ToolCallData parseToolCallData(ChatMessageEntity m) {
        String type = m.getMessageType();
        if (!"TOOL_CALL".equals(type) && !"TOOL_RESULT".equals(type)) {
            return null;
        }
        try {
            JsonNode node = objectMapper.readTree(m.getContent());
            String toolCallId = node.path("toolCallId").asText(null);
            String toolName   = node.path("name").asText(null);
            if ("TOOL_CALL".equals(type)) {
                String arguments = node.path("arguments").asText(null);
                return new ToolCallData(toolCallId, toolName, arguments, null);
            } else {
                // TOOL_RESULT
                String result = node.path("result").asText(null);
                // 瓒呴暱缁撴灉鎴柇锛堥槻姝㈣繃澶х殑宸ュ叿杩斿洖鍊煎崰鐢ㄨ繃澶氬甫瀹斤級
                if (result != null && result.length() > 500) {
                    result = result.substring(0, 500) + "...(truncated)";
                }
                return new ToolCallData(toolCallId, toolName, null, result);
            }
        } catch (Exception e) {
            log.warn("瑙ｆ瀽 ToolCallData 澶辫触: messageUuid={}, error={}", m.getUuid(), e.getMessage());
            return null;
        }
    }

    private long parseUserId() {
        String raw = UserContext.getRequiredUserId();
        try {
            return Long.parseLong(raw);
        } catch (NumberFormatException e) {
            throw new BusinessException(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED,
                    "userId=" + raw);
        }
    }
}

