package com.doublez.pocketmindserver.ai.api;

import com.doublez.pocketmindserver.ai.api.dto.chat.ChatMessageResponse;
import com.doublez.pocketmindserver.ai.api.dto.chat.ChatMessageResponse.ToolCallData;
import com.doublez.pocketmindserver.ai.api.dto.chat.ChatSessionResponse;
import com.doublez.pocketmindserver.ai.api.dto.chat.CreateSessionRequest;
import com.doublez.pocketmindserver.ai.api.dto.chat.SendMessageRequest;
import com.doublez.pocketmindserver.ai.api.dto.chat.UpdateSessionRequest;
import com.doublez.pocketmindserver.ai.application.AiChatService;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageEntity;
import com.doublez.pocketmindserver.chat.domain.message.ChatMessageRepository;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionEntity;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.shared.domain.PageQuery;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Flux;

import java.util.List;
import java.util.UUID;

/**
 * 聊天会话 & 消息接口。
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

    private final ChatSessionRepository chatSessionRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final AiChatService aiChatService;
    private final ObjectMapper objectMapper;

    // 会话管理

    /**
     * 创建会话（全局对话或关联某篇笔记）。
     */
    @PostMapping
    public ResponseEntity<ChatSessionResponse> createSession(
            @RequestBody CreateSessionRequest request) {
        long userId = parseUserId();
        UUID sessionUuid = UUID.randomUUID();
        String title = request.title() != null ? request.title() : "";

        ChatSessionEntity session = ChatSessionEntity.create(
                sessionUuid, userId, request.noteUuid(), title);
        chatSessionRepository.save(session);

        log.info("创建会话: userId={}, sessionUuid={}, noteUuid={}",
                userId, sessionUuid, request.noteUuid());
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

        List<ChatSessionEntity> sessions = noteUuid != null
                ? chatSessionRepository.findByNoteUuid(userId, noteUuid)
                : chatSessionRepository.findByUserId(userId, new PageQuery(size, page));

        return sessions.stream().map(this::toSessionResponse).toList();
    }

    /**
     * 重命名会话标题。
     */
    @PatchMapping("/{sessionUuid}")
    public void renameSession(
            @PathVariable UUID sessionUuid,
            @RequestBody UpdateSessionRequest request) {
        long userId = parseUserId();

        ChatSessionEntity session = chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "sessionUuid=" + sessionUuid));

        session.updateTitle(request.title() != null ? request.title() : "");
        chatSessionRepository.update(session);

        log.info("重命名会话: userId={}, sessionUuid={}, title={}", userId, sessionUuid, request.title());
    }

    /**
     * 软删除会话。
     */
    @DeleteMapping("/{sessionUuid}")
    public void deleteSession(@PathVariable UUID sessionUuid) {
        long userId = parseUserId();

        // 校验归属权
        chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "sessionUuid=" + sessionUuid));

        chatSessionRepository.deleteByUuidAndUserId(sessionUuid, userId);

        log.info("删除会话: userId={}, sessionUuid={}", userId, sessionUuid);
    }

    // 消息管理

    /**
     * 列出会话下的所有消息（按时间正序，最多 500 条）。
     */
    @GetMapping("/{sessionUuid}/messages")
    public List<ChatMessageResponse> listMessages(@PathVariable UUID sessionUuid) {
        long userId = parseUserId();

        // 校验 session 归属
        chatSessionRepository.findByUuidAndUserId(sessionUuid, userId)
                .orElseThrow(() -> new BusinessException(
                        ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "sessionUuid=" + sessionUuid));

        return chatMessageRepository.findBySessionUuid(userId, sessionUuid, new PageQuery(500, 0))
                .stream()
                .map(this::toMessageResponse)
                .toList();
    }

    /**
     * 发送用户消息并流式接收 AI 回复（SSE）。
     *
     * <p>SSE 事件格式：
     * <pre>
     *   event: delta
     *   data: <文字片段>
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
            @Valid @RequestBody SendMessageRequest request) {
        long userId = parseUserId();

        log.info("收到对话消息: userId={}, sessionUuid={}, contentLen={}",
                userId, sessionUuid, request.content().length());

        return aiChatService.streamReply(
                userId,
                sessionUuid,
                request.content(),
                request.safeAttachmentUuids());
    }

    // 私有转换 & 工具方法

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
                parseToolCallData(m));
    }

    /**
     * 解析工具调用元数据。
     * TOOL_CALL 和 TOOL_RESULT 类型的消息 content 为 JSON，解析为结构化数据供客户端渲染 UI。
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
