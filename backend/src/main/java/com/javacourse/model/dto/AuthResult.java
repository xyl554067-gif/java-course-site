package com.javacourse.model.dto;

import java.util.Map;

/**
 * 登录成功返回
 */
public class AuthResult {

    private String token;
    private long expiresIn;
    private Map<String, Object> user;

    public AuthResult(String token, long expiresIn, Map<String, Object> user) {
        this.token = token;
        this.expiresIn = expiresIn;
        this.user = user;
    }

    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }
    public long getExpiresIn() { return expiresIn; }
    public void setExpiresIn(long expiresIn) { this.expiresIn = expiresIn; }
    public Map<String, Object> getUser() { return user; }
    public void setUser(Map<String, Object> user) { this.user = user; }
}
