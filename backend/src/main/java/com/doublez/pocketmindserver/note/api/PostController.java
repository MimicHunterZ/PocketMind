package com.doublez.pocketmindserver.note.api;

import com.doublez.pocketmindserver.note.api.dto.PostResponse;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/post")
@RequiredArgsConstructor
public class PostController {

    private final NoteRepository noteRepository;
    private final ChatSessionRepository chatSessionRepository;

    @GetMapping("/{uuid}")
    public PostResponse getPost(@PathVariable("uuid") UUID uuid) {
        long userId = parseUserId(UserContext.getRequiredUserId());
        var note = noteRepository.findByUuidAndUserId(uuid, userId)
                .orElseThrow(() -> new BusinessException(ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "uuid=" + uuid));

        String aiStatus = computeAiStatus(note);
        UUID sessionUuid = chatSessionRepository.findByNoteUuid(userId, uuid)
                .stream()
                .findFirst()
                .map(s -> s.getUuid())
                .orElse(null);

        return new PostResponse(
                note.getUuid(),
                note.getSourceUrl(),
                aiStatus,
                note.getSummary(),
                sessionUuid,
                note.getResourceStatus(),
                note.getPreviewTitle(),
                note.getPreviewDescription()
        );
    }

    private String computeAiStatus(com.doublez.pocketmindserver.note.domain.note.NoteEntity note) {
        if (note.getSummary() != null && !note.getSummary().isBlank()) {
            return "COMPLETED";
        }
        if (note.getResourceStatus() == com.doublez.pocketmindserver.note.domain.note.NoteResourceStatus.FAILED) {
            return "FAILED";
        }
        // 已受理但未写 summary，统一视为处理中
        return "PROCESSING";
    }

    private long parseUserId(String userId) {
        try {
            return Long.parseLong(userId);
        } catch (NumberFormatException e) {
            throw new BusinessException(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "非法 userId");
        }
    }
}
