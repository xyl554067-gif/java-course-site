package com.javacourse.repository;

import com.javacourse.model.dto.AuthResult;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.sql.PreparedStatement;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 用户仓储
 */
@Repository
public class UserRepository {

    private final JdbcTemplate jdbc;

    public UserRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final RowMapper<Map<String, Object>> USER_MAPPER = (rs, i) -> {
        Map<String, Object> m = new HashMap<>();
        m.put("id", rs.getLong("id"));
        m.put("username", rs.getString("username"));
        m.put("passwordHash", rs.getString("password_hash"));
        m.put("salt", rs.getString("salt"));
        m.put("nickname", rs.getString("nickname"));
        m.put("email", rs.getString("email"));
        m.put("avatar", rs.getString("avatar"));
        m.put("role", rs.getString("role"));
        m.put("status", rs.getString("status"));
        m.put("lastLoginAt", rs.getTimestamp("last_login_at"));
        m.put("createdAt", rs.getTimestamp("created_at"));
        return m;
    };

    public Optional<Map<String, Object>> findByUsername(String username) {
        List<Map<String, Object>> list = jdbc.query(
                "SELECT id, username, password_hash, salt, nickname, email, avatar, role, status, "
                        + "last_login_at, created_at FROM app_user WHERE username = ?",
                USER_MAPPER, username);
        return list.isEmpty() ? Optional.empty() : Optional.of(list.get(0));
    }

    public Optional<Map<String, Object>> findById(long id) {
        List<Map<String, Object>> list = jdbc.query(
                "SELECT id, username, password_hash, salt, nickname, email, avatar, role, status, "
                        + "last_login_at, created_at FROM app_user WHERE id = ?",
                USER_MAPPER, id);
        return list.isEmpty() ? Optional.empty() : Optional.of(list.get(0));
    }

    public long insert(String username, String passwordHash, String salt, String nickname, String email, String role) {
        KeyHolder kh = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(
                    "INSERT INTO app_user (username, password_hash, salt, nickname, email, role, status) "
                            + "VALUES (?, ?, ?, ?, ?, ?, 'active')",
                    new String[]{"id"});
            ps.setString(1, username);
            ps.setString(2, passwordHash);
            ps.setString(3, salt);
            ps.setString(4, nickname);
            ps.setString(5, email);
            ps.setString(6, role);
            return ps;
        }, kh);
        Number key = kh.getKey();
        if (key == null) {
            throw new IllegalStateException("创建用户失败：未返回自增 ID");
        }
        return key.longValue();
    }

    public void touchLogin(long userId) {
        jdbc.update("UPDATE app_user SET last_login_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                userId);
    }

    /** 保存会话记录，便于服务端审计与主动登出 */
    public void saveSession(String token, long userId, String userAgent, String clientIp, long expiresAt) {
        jdbc.update("INSERT INTO user_session (token, user_id, user_agent, client_ip, expires_at) "
                        + "VALUES (?, ?, ?, ?, ?)",
                token, userId, truncate(userAgent, 255), clientIp,
                new java.sql.Timestamp(expiresAt * 1000L));
    }

    public void deleteSession(String token) {
        jdbc.update("DELETE FROM user_session WHERE token = ?", token);
    }

    public void cleanExpiredSessions() {
        jdbc.update("DELETE FROM user_session WHERE expires_at < CURRENT_TIMESTAMP");
    }

    private static String truncate(String s, int max) {
        if (s == null) {
            return null;
        }
        return s.length() <= max ? s : s.substring(0, max);
    }
}
