package com.javacourse.service;

import com.javacourse.model.dto.AuthRequest;
import com.javacourse.model.dto.AuthResult;
import com.javacourse.repository.UserRepository;
import com.javacourse.security.PasswordUtil;
import com.javacourse.security.TokenService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * 认证服务：注册 / 登录 / 登出 / 当前用户
 */
@Service
public class AuthService {

    private final UserRepository users;
    private final TokenService tokens;

    public AuthService(UserRepository users, TokenService tokens) {
        this.users = users;
        this.tokens = tokens;
    }

    @Transactional
    public AuthResult register(AuthRequest req) {
        if (users.findByUsername(req.getUsername()).isPresent()) {
            throw new IllegalArgumentException("用户名已被占用");
        }
        String salt = PasswordUtil.newSalt();
        String hash = PasswordUtil.hash(req.getPassword(), salt);
        String nickname = (req.getNickname() == null || req.getNickname().isBlank())
                ? req.getUsername() : req.getNickname().trim();
        long id = users.insert(req.getUsername(), hash, salt, nickname, null, "student");
        return buildResult(id, req.getUsername(), nickname, "student", null, null, null);
    }

    public AuthResult login(AuthRequest req, String userAgent, String clientIp) {
        Optional<Map<String, Object>> found = users.findByUsername(req.getUsername());
        if (found.isEmpty()) {
            throw new IllegalArgumentException("用户名或密码错误");
        }
        Map<String, Object> u = found.get();
        if (!"active".equals(u.get("status"))) {
            throw new IllegalArgumentException("账号已被禁用，请联系管理员");
        }
        String hash = String.valueOf(u.get("passwordHash"));
        if (!PasswordUtil.verify(req.getPassword(), hash)) {
            throw new IllegalArgumentException("用户名或密码错误");
        }
        long id = (Long) u.get("id");
        String nickname = u.get("nickname") != null ? String.valueOf(u.get("nickname")) : req.getUsername();
        String role = String.valueOf(u.get("role"));
        users.touchLogin(id);
        return buildResult(id, req.getUsername(), nickname, role, userAgent, clientIp,
                u.get("avatar") != null ? String.valueOf(u.get("avatar")) : null);
    }

    private AuthResult buildResult(long id, String username, String nickname, String role,
                                   String userAgent, String clientIp, String avatar) {
        String token = tokens.issue(id, username, role);
        users.saveSession(token, id, userAgent, clientIp,
                Instant.now().getEpochSecond() + tokens.expireSeconds());

        Map<String, Object> profile = new HashMap<>();
        profile.put("id", id);
        profile.put("username", username);
        profile.put("nickname", nickname);
        profile.put("role", role);
        profile.put("avatar", avatar);
        return new AuthResult(token, tokens.expireSeconds(), profile);
    }

    public Map<String, Object> currentUser(long userId) {
        return users.findById(userId).map(u -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", u.get("id"));
            m.put("username", u.get("username"));
            m.put("nickname", u.get("nickname"));
            m.put("role", u.get("role"));
            m.put("avatar", u.get("avatar"));
            m.put("email", u.get("email"));
            m.put("lastLoginAt", u.get("lastLoginAt"));
            return m;
        }).orElseGet(HashMap::new);
    }

    public void logout(String token) {
        if (token != null) {
            users.deleteSession(token);
        }
    }
}
