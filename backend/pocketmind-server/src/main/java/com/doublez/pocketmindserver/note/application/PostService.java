package com.doublez.pocketmindserver.note.application;

import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
import com.doublez.pocketmindserver.chat.domain.session.ChatSessionRepository;
import com.doublez.pocketmindserver.note.api.dto.PostResponse;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PostService {

    private final NoteRepository noteRepository;
    private final ChatSessionRepository chatSessionRepository;

    public PostResponse getPost(UUID uuid, long userId) {
        var note = noteRepository.findByUuidAndUserId(uuid, userId)
                .orElseThrow(() -> new BusinessException(ApiCode.RESOURCE_NOT_FOUND, HttpStatus.NOT_FOUND, "uuid=" + uuid));
        
        String aiStatus = computeAiStatus(note);
        
        UUID sessionUuid = chatSessionRepository.findByNoteUuid(userId, uuid)
                .stream()
                .findFirst()
                .map(s -> s.getUuid())
                .orElse(null);

        List<String> tags = noteRepository.findTagNamesByUuid(uuid, userId);

        return new PostResponse(
                note.getUuid(),
                note.getSourceUrl(),
                aiStatus,
                note.getSummary(),
                sessionUuid,
                note.getResourceStatus(),
                note.getPreviewTitle(),
                note.getPreviewDescription(),
                tags
        );
    }

    private String computeAiStatus(com.doublez.pocketmindserver.note.domain.note.NoteEntity note) {
        if (note.getSummary() != null && !note.getSummary().isBlank()) {
            return "COMPLETED";
        }
        if (note.getResourceStatus() == com.doublez.pocketmindserver.note.domain.note.NoteResourceStatus.FAILED) {
            return "FAILED";
        }
        return "PROCESSING";
    }
}
