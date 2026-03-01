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
 * 聊天会话与消息接口。
 *
 * <pre>
 * POST   /api/ai/sessions                            创建会话
 * GET    /api/ai/sessions[?noteUuid=&page=&size=]    列出会话
 * GET    /api/ai/sessions/{uuid}/messages            列出消息
 * POST   /api/ai/sessions/{uuid}/messages            发送消息（SSE 流式返回）
 * PATCH  /api/ai/sessions/{uuid}                     重命名会话
 * DELETE /api/ai/sessions/{uuid}                     软删除会话
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

    // 会话管理

    /**
     * 创建会话（全局对话或关联某篇笔记）。
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
     * 列出当前用户的会话，可按笔记过滤。
     *
     * @param noteUuid 关联笔记 UUID（可选）
     * @param page     页码（从 0 开始，默认 0）
     * @param size     每页条数（默认 50）
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
     * 获取单个会话详情。
     */
    @GetMapping("/{sessionUuid}")
    public ChatSessionResponse getSession(@PathVariable UUID sessionUuid) {
        long userId = parseUserId();
        return toSessionResponse(aiChatService.getSession(userId, sessionUuid));
    }

    /**
     * 重命名会话标题。
     */
    @PatchMapping("/{sessionUuid}")
    public void renameSession(
            @PathVariable UUID sessionUuid,
            @Valid @RequestBody UpdateSessionRequest request) {
        long userId = parseUserId();
        aiChatService.renameSession(userId, sessionUuid, request.title());
    }

    /**
     * 软删除会话。
     */
    @DeleteMapping("/{sessionUuid}")
    public void deleteSession(@PathVariable UUID sessionUuid) {
        long userId = parseUserId();
        aiChatService.deleteSession(userId, sessionUuid);
    }

    // 消息管理

    /**
     * 列出会话下的所有消息（按时间正序，最多 500 条）。
     * 若传入 leafUuid，则返回从叶节点到链头的完整分支消息链（用于分支模式）。
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
      * 发送用户消息并流式接收 AI 回复（SSE）。
     *
      * <p>SSE 事件格式：</p>
     * <pre>
     *   event: delta
      *   data: <文本片段>
      *
     *   event: done
      *   data: {"messageUuid":"<uuid>"}
     *
     *   event: error
      *   data: {"message":"<错误信息>"}
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

        log.info("收到对话消息: userId={}, sessionUuid={}, contentLen={}",
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
     * 单独生成并更新会话标题。
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
     * 编辑 USER 消息内容（同时删除紧随其后的 ASSISTANT 消息，等待客户端触发重新生成）。
     */
    @PatchMapping("/{sessionUuid}/messages/{messageUuid}")
    public void editMessage(
            @PathVariable UUID sessionUuid,
            @PathVariable UUID messageUuid,
            @Valid @RequestBody EditMessageRequest request) {
        long userId = parseUserId();
        aiChatService.editUserMessage(userId, messageUuid, request.content());
        log.info("编辑消息: userId={}, messageUuid={}", userId, messageUuid);
    }

    /**
      * 重新生成指定消息的 AI 回复（SSE 流式）。
     *
      * <p>支持两种调用方式：</p>
     * <ul>
      *   <li>ASSISTANT UUID：标准重新生成，软删除旧回复后重新调用 AI。</li>
      *   <li>USER UUID：继续生成，适用于 editAndResend 场景（ASSISTANT 已被 editMessage 清除）。</li>
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
        log.info("重新生成消息: userId={}, sessionUuid={}, messageUuid={}", userId, sessionUuid, messageUuid);
        return aiChatService.regenerateReply(userId, sessionUuid, messageUuid, effectiveRequestId);
    }

    /**
     * 停止指定 requestId 的流式回复。
     */
    @PostMapping("/{sessionUuid}/messages/stop")
    public void stopMessage(
            @PathVariable UUID sessionUuid,
            @Valid @RequestBody StopMessageRequest request) {
        long userId = parseUserId();
        aiChatService.stopReply(userId, sessionUuid, request.requestId());
    }

    /**
     * 对消息评分（点赞/点踩/取消）。
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
     * 更新分支别名（用户手动编辑，最多 10 字符）。
     */
    @PatchMapping("/{sessionUuid}/messages/{messageUuid}/alias")
    public void updateAlias(
            @PathVariable UUID sessionUuid,
            @PathVariable UUID messageUuid,
            @Valid @RequestBody UpdateAliasRequest request) {
        long userId = parseUserId();
        aiChatService.updateBranchAlias(userId, messageUuid, request.alias());
        log.info("更新分支别名: userId={}, messageUuid={}", userId, messageUuid);
    }

    /**
     * 获取会话的所有分支摘要列表。
     */
    @GetMapping("/{sessionUuid}/branches")
    public List<ChatBranchSummaryResponse> getBranches(@PathVariable UUID sessionUuid) {
        long userId = parseUserId();
        return aiChatService.getBranches(userId, sessionUuid);
    }

    // 私有转换与工具方法

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
     * 解析工具调用元数据。
     * TOOL_CALL / TOOL_RESULT 类型的消息 content 为 JSON，解析为结构化数据供客户端渲染 UI。
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
                // 超长结果截断（防止过大的工具返回值占用过多带宽）
                if (result != null && result.length() > 500) {
                    result = result.substring(0, 500) + "...(truncated)";
                }
                return new ToolCallData(toolCallId, toolName, null, result);
            }
        } catch (Exception e) {
            log.warn("解析 ToolCallData 失败: messageUuid={}, error={}", m.getUuid(), e.getMessage());
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

