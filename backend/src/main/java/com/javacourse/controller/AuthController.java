package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.model.dto.AuthRequest;
import com.javacourse.model.dto.AuthResult;
import com.javacourse.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 认证接口
 */
@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    public ApiResponse<AuthResult> login(@Valid @RequestBody AuthRequest req, HttpServletRequest http) {
        try {
            AuthResult r = authService.login(req, http.getHeader("User-Agent"), http.getRemoteAddr());
            return ApiResponse.ok(r);
        } catch (IllegalArgumentException e) {
            return ApiResponse.error(400, e.getMessage());
        }
    }

    @PostMapping("/register")
    public ApiResponse<AuthResult> register(@Valid @RequestBody AuthRequest req) {
        try {
            return ApiResponse.ok(authService.register(req));
        } catch (IllegalArgumentException e) {
            return ApiResponse.error(400, e.getMessage());
        }
    }

    @PostMapping("/logout")
    public ApiResponse<Void> logout(@RequestParam(required = false) String token) {
        authService.logout(token);
        return ApiResponse.ok();
    }

    @GetMapping("/me")
    public ApiResponse<Map<String, Object>> me(HttpServletRequest http) {
        Object uid = http.getAttribute("userId");
        if (uid == null) {
            return ApiResponse.error(401, "未登录");
        }
        return ApiResponse.ok(authService.currentUser((Long) uid));
    }
}
