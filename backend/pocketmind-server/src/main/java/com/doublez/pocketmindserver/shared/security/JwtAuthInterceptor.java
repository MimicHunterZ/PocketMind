package com.doublez.pocketmindserver.shared.security;

import com.doublez.pocketmind.common.security.JwtTokenService;
import com.doublez.pocketmind.common.web.UnauthorizedException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class JwtAuthInterceptor implements HandlerInterceptor {

    private static final String AUTH_HEADER = "Authorization";
    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtTokenService tokenService;

    public JwtAuthInterceptor(JwtTokenService tokenService) {
        this.tokenService = tokenService;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }

        String auth = request.getHeader(AUTH_HEADER);
        if (auth == null || !auth.startsWith(BEARER_PREFIX)) {
            throw new UnauthorizedException("缺少 Authorization Bearer Token");
        }

        String token = auth.substring(BEARER_PREFIX.length()).trim();
        String userId = tokenService.verifyAndGetUserId(token);
        UserContext.setUserId(userId);
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) {
        UserContext.clear();
    }
}

