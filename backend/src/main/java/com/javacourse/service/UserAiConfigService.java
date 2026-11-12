package com.javacourse.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.net.InetAddress;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

/** Account-owned OpenAI-compatible model settings. API keys are encrypted before they reach the database. */
@Service
public class UserAiConfigService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private final JdbcTemplate jdbc;
    private final String encryptionSecret;

    public UserAiConfigService(JdbcTemplate jdbc,
            @Value("${app.ai.user-config-encryption-key:}") String encryptionSecret) {
        this.jdbc = jdbc;
        this.encryptionSecret = encryptionSecret == null ? "" : encryptionSecret.trim();
    }

    public record ModelConfig(String baseUrl, String model, String apiKey) {
        @Override
        public String toString() {
            return "ModelConfig[credentials hidden]";
        }
    }

    public Map<String, Object> status(long userId) {
        Map<String, Object> result = new HashMap<>();
        result.put("configured", hasConfig(userId));
        result.put("encryptionReady", encryptionSecret.length() >= 32);
        jdbc.query("SELECT base_url,model,encrypted_key FROM user_ai_config WHERE user_id=?", rs -> {
            result.put("baseUrl", rs.getString("base_url"));
            result.put("model", rs.getString("model"));
            String encrypted = rs.getString("encrypted_key");
            result.put("apiKeyConfigured", encrypted != null && !encrypted.isBlank());
            result.put("apiKeyHint", encrypted == null || encrypted.isBlank() ? "" : "已保存（隐藏）");
        }, userId);
        return result;
    }

    public ModelConfig get(long userId) {
        if (userId <= 0) return null;
        var rows = jdbc.query("SELECT base_url,model,encrypted_key FROM user_ai_config WHERE user_id=?",
                (rs, row) -> new ModelConfig(rs.getString("base_url"), rs.getString("model"), decrypt(rs.getString("encrypted_key"))), userId);
        if (rows.isEmpty()) return null;
        ModelConfig config = rows.get(0);
        return new ModelConfig(validateBaseUrl(config.baseUrl()), config.model(), config.apiKey());
    }

    @Transactional
    public Map<String, Object> save(long userId, String baseUrl, String model, String apiKey) {
        String url = validateBaseUrl(baseUrl);
        String modelName = clean(model, 160);
        if (modelName.isBlank()) throw new IllegalArgumentException("请填写模型名称");
        String key = keyForEndpoint(userId, url, apiKey);
        ensureEncryptionConfigured();
        String encrypted = encrypt(key);
        jdbc.update("INSERT INTO user_ai_config(user_id,base_url,model,encrypted_key,updated_at) VALUES(?,?,?,?,CURRENT_TIMESTAMP) "
                        + "ON CONFLICT(user_id) DO UPDATE SET base_url=EXCLUDED.base_url,model=EXCLUDED.model,encrypted_key=EXCLUDED.encrypted_key,updated_at=CURRENT_TIMESTAMP",
                userId, url, modelName, encrypted);
        return status(userId);
    }

    @Transactional
    public void delete(long userId) {
        jdbc.update("DELETE FROM user_ai_config WHERE user_id=?", userId);
    }

    public ModelConfig proposed(String baseUrl, String model, String apiKey, long userId) {
        String url = validateBaseUrl(baseUrl);
        String modelName = clean(model, 160);
        if (modelName.isBlank()) throw new IllegalArgumentException("请填写模型名称");
        return new ModelConfig(url, modelName, keyForEndpoint(userId, url, apiKey));
    }

    private String keyForEndpoint(long userId, String url, String input) {
        String key = input == null ? "" : input.trim();
        if (!key.isEmpty()) {
            if (key.length() > 3000 || !key.matches("[!-~]+")) {
                throw new IllegalArgumentException("API Key 格式无效");
            }
            return key;
        }
        var stored = jdbc.query("SELECT base_url,encrypted_key FROM user_ai_config WHERE user_id=?",
                (rs, row) -> Map.entry(rs.getString("base_url"), rs.getString("encrypted_key")), userId);
        if (!stored.isEmpty()) {
            var entry = stored.get(0);
            if (!url.equals(entry.getKey())) {
                throw new IllegalArgumentException("更换接口地址时，请填写该服务商的 API Key");
            }
            String saved = decrypt(entry.getValue());
            if (!saved.isBlank()) return saved;
        }
        throw new IllegalArgumentException("请填写 API Key");
    }

    public String validateBaseUrl(String value) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException("请填写兼容接口地址");
        String raw = value.trim().replaceAll("/+$", "");
        if (raw.length() > 1000) throw new IllegalArgumentException("接口地址太长");
        URI uri;
        try {
            uri = URI.create(raw);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("接口地址无效，请使用公开 HTTPS 地址");
        }
        if (!"https".equalsIgnoreCase(uri.getScheme()) || uri.getHost() == null
                || uri.getUserInfo() != null || uri.getFragment() != null || uri.getQuery() != null) {
            throw new IllegalArgumentException("接口地址必须是公开 HTTPS 地址，且不能包含凭据、查询参数或片段");
        }
        try {
            PublicModelDns.requirePublic(InetAddress.getAllByName(uri.getHost()));
            return raw;
        } catch (java.net.UnknownHostException e) {
            throw new IllegalArgumentException("接口地址无效或无法解析，请使用公开 HTTPS 地址");
        }
    }

    private boolean hasConfig(long userId) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM user_ai_config WHERE user_id=?", Integer.class, userId);
        return n != null && n > 0;
    }

    private String encrypt(String plain) {
        try {
            byte[] nonce = new byte[12]; RANDOM.nextBytes(nonce);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(derivedKey(), "AES"), new GCMParameterSpec(128, nonce));
            byte[] encrypted = cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));
            byte[] packed = new byte[nonce.length + encrypted.length];
            System.arraycopy(nonce, 0, packed, 0, nonce.length);
            System.arraycopy(encrypted, 0, packed, nonce.length, encrypted.length);
            return Base64.getEncoder().encodeToString(packed);
        } catch (Exception e) { throw new IllegalStateException("API Key 加密失败"); }
    }

    private String decrypt(String packedValue) {
        if (packedValue == null || packedValue.isBlank()) return "";
        ensureEncryptionConfigured();
        try {
            byte[] packed = Base64.getDecoder().decode(packedValue);
            byte[] nonce = java.util.Arrays.copyOfRange(packed, 0, 12);
            byte[] encrypted = java.util.Arrays.copyOfRange(packed, 12, packed.length);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(derivedKey(), "AES"), new GCMParameterSpec(128, nonce));
            return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);
        } catch (Exception e) { throw new IllegalStateException("无法读取已保存的 API Key，请重新填写"); }
    }

    private byte[] derivedKey() throws Exception {
        ensureEncryptionConfigured();
        return MessageDigest.getInstance("SHA-256").digest(encryptionSecret.getBytes(StandardCharsets.UTF_8));
    }

    private void ensureEncryptionConfigured() {
        if (encryptionSecret.length() < 32) {
            throw new IllegalStateException("站点暂不能保存账号 API Key");
        }
    }

    private String clean(String value, int max) {
        if (value == null) return "";
        String result = value.trim();
        return result.length() > max ? result.substring(0, max) : result;
    }
}
