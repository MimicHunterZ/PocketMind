package com.doublez.pocketmind.common.security;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.doublez.pocketmind.common.web.UnauthorizedException;
import org.springframework.stereotype.Component;

import java.time.Instant;

@Component
public class JwtTokenService {

    private final JwtProperties properties;
    private final JWTVerifier verifier;
    private final Algorithm algorithm;

    public JwtTokenService(JwtProperties properties) {
        if (properties.secret() == null || properties.secret().isBlank()) {
            throw new IllegalStateException("pocketmind.jwt.secret 未配置");
        }
        if (properties.tokenTtlSeconds() <= 0) {
            throw new IllegalStateException("pocketmind.jwt.token-ttl-seconds 未配置或不合法");
        }
        this.properties = properties;

        this.algorithm = Algorithm.HMAC256(properties.secret());
        this.verifier = JWT.require(this.algorithm)
                .acceptLeeway(properties.leewaySeconds())
                .build();
    }

    public String issueToken(String userId) {
        Instant now = Instant.now();
        Instant expiresAt = now.plusSeconds(properties.tokenTtlSeconds());

        return JWT.create()
                .withIssuedAt(now)
                .withExpiresAt(expiresAt)
                .withSubject(userId)
                .withClaim(properties.userIdClaim(), userId)
                .sign(algorithm);
    }

    public long tokenTtlSeconds() {
        return properties.tokenTtlSeconds();
    }

    public String verifyAndGetUserId(String token) {
        DecodedJWT jwt;
        try {
            jwt = verifier.verify(token);
        } catch (JWTVerificationException e) {
            throw new UnauthorizedException("Token 无效");
        }

        Instant expiresAt = jwt.getExpiresAtAsInstant();
        if (expiresAt == null || expiresAt.isBefore(Instant.now())) {
            throw new UnauthorizedException("Token 已过期");
        }

        String claimName = properties.userIdClaim();
        String userId = (claimName == null || claimName.isBlank()) ? null : jwt.getClaim(claimName).asString();
        if (userId == null || userId.isBlank()) {
            userId = jwt.getSubject();
        }
        if (userId == null || userId.isBlank()) {
            throw new UnauthorizedException("Token 缺少 userId");
        }
        return userId;
    }
}

