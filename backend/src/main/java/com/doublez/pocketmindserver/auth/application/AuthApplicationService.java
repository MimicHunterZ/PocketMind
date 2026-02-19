package com.doublez.pocketmindserver.auth.application;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.doublez.pocketmindserver.auth.api.dto.AuthTokenResponse;
import com.doublez.pocketmindserver.auth.api.dto.LoginRequest;
import com.doublez.pocketmindserver.auth.api.dto.RegisterRequest;
import com.doublez.pocketmindserver.auth.infra.persistence.UserAccount;
import com.doublez.pocketmindserver.auth.infra.persistence.UserAccountRepository;
import com.doublez.pocketmindserver.shared.security.JwtTokenService;
import com.doublez.pocketmindserver.shared.web.ApiCode;
import com.doublez.pocketmindserver.shared.web.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
public class AuthApplicationService {

    private final UserAccountRepository userAccountRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenService jwtTokenService;

    public AuthApplicationService(UserAccountRepository userAccountRepository,
                                  PasswordEncoder passwordEncoder,
                                  JwtTokenService jwtTokenService) {
        this.userAccountRepository = userAccountRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenService = jwtTokenService;
    }

    public AuthTokenResponse register(RegisterRequest request) {
        UserAccount existing = userAccountRepository.selectOne(new LambdaQueryWrapper<UserAccount>()
                .eq(UserAccount::getUsername, request.username()));
        if (existing != null) {
            throw new BusinessException(ApiCode.AUTH_USERNAME_EXISTS, HttpStatus.CONFLICT);
        }

        UserAccount account = new UserAccount();
        account.setUuid(UUID.randomUUID());
        account.setUsername(request.username());
        account.setPasswordHash(passwordEncoder.encode(request.password()));
        account.setCreatedAt(LocalDateTime.now());
        account.setUpdatedAt(System.currentTimeMillis());

        int inserted = userAccountRepository.insert(account);
        if (inserted != 1) {
            throw new BusinessException(ApiCode.AUTH_REGISTER_FAILED, HttpStatus.INTERNAL_SERVER_ERROR);
        }

        String token = jwtTokenService.issueToken(account.getId().toString());
        return new AuthTokenResponse(account.getId().toString(), token, jwtTokenService.tokenTtlSeconds());
    }

    public AuthTokenResponse login(LoginRequest request) {
        UserAccount account = userAccountRepository.selectOne(new LambdaQueryWrapper<UserAccount>()
                .eq(UserAccount::getUsername, request.username()));
        if (account == null) {
            throw new BusinessException(ApiCode.AUTH_BAD_CREDENTIALS, HttpStatus.UNAUTHORIZED);
        }

        if (!passwordEncoder.matches(request.password(), account.getPasswordHash())) {
            throw new BusinessException(ApiCode.AUTH_BAD_CREDENTIALS, HttpStatus.UNAUTHORIZED);
        }

        String token = jwtTokenService.issueToken(account.getId().toString());
        return new AuthTokenResponse(account.getId().toString(), token, jwtTokenService.tokenTtlSeconds());
    }
}

