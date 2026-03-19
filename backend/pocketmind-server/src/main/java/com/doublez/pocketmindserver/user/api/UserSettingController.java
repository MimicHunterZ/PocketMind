package com.doublez.pocketmindserver.user.api;

import com.doublez.pocketmindserver.shared.security.UserContext;
import com.doublez.pocketmindserver.user.api.dto.UserSettingDto;
import com.doublez.pocketmindserver.user.application.UserSettingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/user/settings")
@RequiredArgsConstructor
public class UserSettingController {

    private final UserSettingService userSettingService;
    
    private long parseUserId() {
        return Long.parseLong(UserContext.getRequiredUserId());
    }

    @GetMapping
    public ResponseEntity<UserSettingDto> getSettings() {
        long userId = parseUserId();
        return ResponseEntity.ok(userSettingService.getSettings(userId));
    }
}
