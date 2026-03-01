package com.doublez.pocketmindserver.auth.api;

import com.doublez.pocketmindserver.auth.application.AuthApplicationService;
import com.doublez.pocketmindserver.auth.api.dto.AuthTokenResponse;
import com.doublez.pocketmindserver.auth.api.dto.LoginRequest;
import com.doublez.pocketmindserver.auth.api.dto.RegisterRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthApplicationService authApplicationService;

    public AuthController(AuthApplicationService authApplicationService) {
        this.authApplicationService = authApplicationService;
    }

    @PostMapping("/register")
    public AuthTokenResponse register(@Valid @RequestBody RegisterRequest request) {
        return authApplicationService.register(request);
    }

    @PostMapping("/login")
    public AuthTokenResponse login(@Valid @RequestBody LoginRequest request) {
        return authApplicationService.login(request);
    }
}
