package com.javacourse.security;

import com.javacourse.config.AppProperties;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.UUID;

/**
 * 会话令牌服务：自实现的 HMAC-SHA256 签名令牌（无第三方依赖）
 * <p>格式：{@code base64url(payload).base64url(hmac)}</p>
 * <p>payload 为 {@code userId|username|role|issuedAtEpochSecond|expireEpochSecond|nonce}</p>
 */
@Component
public class TokenService {

    private static final String HMAC_ALGO = "HmacSHA256";

    private final byte[] secret;
    private final int expireHours;

    public TokenService(AppProperties props) {
        this.secret = props.getJwt().getSecret().getBytes(StandardCharsets.UTF_8);
        this.expireHours = props.getJwt().getExpireHours();
    }

    public String issue(long userId, String username, String role) {
        long now = Instant.now().getEpochSecond();
        long exp = Instant.now().plus(expireHours, ChronoUnit.HOURS).getEpochSecond();
        String payload = userId + "|" + username + "|" + role + "|" + now + "|" + exp + "|"
                + UUID.randomUUID().toString().replace("-", "");
        String body = b64(payload.getBytes(StandardCharsets.UTF_8));
        return body + "." + b64(sign(body.getBytes(StandardCharsets.UTF_8)));
    }

    /**
     * 校验并解析令牌，失败返回 null
     */
    public TokenPayload verify(String token) {
        if (token == null || !token.contains(".")) {
            return null;
        }
        int idx = token.lastIndexOf('.');
        String body = token.substring(0, idx);
        String sig = token.substring(idx + 1);
        byte[] expected = sign(body.getBytes(StandardCharsets.UTF_8));
        byte[] actual;
        try {
            actual = Base64.getUrlDecoder().decode(sig);
        } catch (IllegalArgumentException e) {
            return null;
        }
        if (!MessageDigest.isEqual(expected, actual)) {
            return null;
        }
        String payload;
        try {
            payload = new String(Base64.getUrlDecoder().decode(body), StandardCharsets.UTF_8);
        } catch (IllegalArgumentException e) {
            return null;
        }
        String[] parts = payload.split("\\|");
        if (parts.length < 6) {
            return null;
        }
        try {
            long exp = Long.parseLong(parts[4]);
            if (Instant.now().getEpochSecond() > exp) {
                return null;
            }
            return new TokenPayload(Long.parseLong(parts[0]), parts[1], parts[2], exp);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public long expireSeconds() {
        return expireHours * 3600L;
    }

    private byte[] sign(byte[] data) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGO);
            mac.init(new SecretKeySpec(secret, HMAC_ALGO));
            return mac.doFinal(data);
        } catch (Exception e) {
            throw new IllegalStateException("令牌签名失败", e);
        }
    }

    private static String b64(byte[] data) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(data);
    }

    public record TokenPayload(long userId, String username, String role, long expireAt) {}
}
