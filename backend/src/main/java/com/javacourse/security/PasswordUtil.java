package com.javacourse.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * 密码哈希工具：PBKDF2-HMAC-SHA256 + 随机盐
 * <p>存储格式：{@code pbkdf2$<iterations>$<saltBase64>$<hashBase64>}</p>
 */
public final class PasswordUtil {

    private static final String ALGO = "PBKDF2WithHmacSHA256";
    private static final int ITERATIONS = 120_000;
    private static final int KEY_LENGTH = 256;
    private static final SecureRandom RANDOM = new SecureRandom();

    private PasswordUtil() {}

    public static String newSalt() {
        byte[] salt = new byte[16];
        RANDOM.nextBytes(salt);
        return Base64.getEncoder().encodeToString(salt);
    }

    public static String hash(String rawPassword, String saltBase64) {
        try {
            byte[] salt = Base64.getDecoder().decode(saltBase64);
            javax.crypto.SecretKeyFactory f = javax.crypto.SecretKeyFactory.getInstance(ALGO);
            javax.crypto.spec.PBEKeySpec spec = new javax.crypto.spec.PBEKeySpec(
                    rawPassword.toCharArray(), salt, ITERATIONS, KEY_LENGTH);
            byte[] dk = f.generateSecret(spec).getEncoded();
            return "pbkdf2$" + ITERATIONS + "$" + saltBase64 + "$"
                    + Base64.getEncoder().encodeToString(dk);
        } catch (Exception e) {
            throw new IllegalStateException("密码哈希失败", e);
        }
    }

    public static boolean verify(String rawPassword, String stored) {
        if (rawPassword == null || stored == null) {
            return false;
        }
        try {
            String[] parts = stored.split("\\$");
            if (parts.length != 4 || !"pbkdf2".equals(parts[0])) {
                return false;
            }
            int iter = Integer.parseInt(parts[1]);
            byte[] salt = Base64.getDecoder().decode(parts[2]);
            byte[] expected = Base64.getDecoder().decode(parts[3]);
            javax.crypto.SecretKeyFactory f = javax.crypto.SecretKeyFactory.getInstance(ALGO);
            javax.crypto.spec.PBEKeySpec spec = new javax.crypto.spec.PBEKeySpec(
                    rawPassword.toCharArray(), salt, iter, expected.length * 8);
            byte[] actual = f.generateSecret(spec).getEncoded();
            return MessageDigest.isEqual(expected, actual);
        } catch (Exception e) {
            return false;
        }
    }
}
