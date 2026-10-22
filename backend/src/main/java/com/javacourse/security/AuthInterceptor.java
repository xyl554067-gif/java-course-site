package com.javacourse.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * 登录态拦截器：除放行路径外，均要求携带有效令牌
 */
@Component
public class AuthInterceptor implements HandlerInterceptor {

    private final TokenService tokenService;

    public AuthInterceptor(TokenService tokenService) {
        this.tokenService = tokenService;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if (!(handler instanceof HandlerMethod)) {
            return true;
        }
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }
        String token = resolveToken(request);
        TokenService.TokenPayload payload = tokenService.verify(token);
        if (payload == null) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json;charset=UTF-8");
            try {
                response.getWriter().write("{\"code\":401,\"message\":\"未登录或登录已过期\"}");
            } catch (Exception ignored) {
                // 响应已提交，忽略
            }
            return false;
        }
        request.setAttribute("userId", payload.userId());
        request.setAttribute("username", payload.username());
        request.setAttribute("role", payload.role());
        return true;
    }

    private String resolveToken(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            return header.substring(7).trim();
        }
        // SSE / EventSource 无法自定义请求头，允许通过查询参数传令牌
        String param = request.getParameter("token");
        return param != null ? param.trim() : null;
    }
}
