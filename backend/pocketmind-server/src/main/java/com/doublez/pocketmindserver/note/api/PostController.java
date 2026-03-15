package com.doublez.pocketmindserver.note.api;

import com.doublez.pocketmindserver.note.api.dto.PostResponse;
import com.doublez.pocketmindserver.note.application.PostService;
import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmind.common.web.ApiCode;
import com.doublez.pocketmind.common.web.BusinessException;
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

    private final PostService postService;

    @GetMapping("/{uuid}")
    public PostResponse getPost(@PathVariable("uuid") UUID uuid) {
        long userId = parseUserId(UserContext.getRequiredUserId());
        return postService.getPost(uuid, userId);
    }

    private long parseUserId(String userId) {
        try {
            return Long.parseLong(userId);
        } catch (NumberFormatException e) {
            throw new BusinessException(ApiCode.AUTH_UNAUTHORIZED, HttpStatus.UNAUTHORIZED, "非法 userId");
        }
    }
}


