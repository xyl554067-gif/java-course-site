package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.service.AssistantRequestLimit;
import com.javacourse.service.ModelGateway;
import com.javacourse.service.UserAiConfigService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/** Private, account-scoped AI provider settings shared by assistant and course generation. */
@RestController
@RequestMapping("/profile/ai-config")
public class UserAiConfigController {
    private final UserAiConfigService configs;
    private final ModelGateway gateway;
    private final AssistantRequestLimit limit;

    public UserAiConfigController(UserAiConfigService configs, ModelGateway gateway, AssistantRequestLimit limit) {
        this.configs = configs;
        this.gateway = gateway;
        this.limit = limit;
    }

    private long uid(HttpServletRequest request) { return (Long) request.getAttribute("userId"); }

    @GetMapping
    public ApiResponse<Map<String, Object>> get(HttpServletRequest request) {
        return ApiResponse.ok(configs.status(uid(request)));
    }

    @PutMapping
    public ApiResponse<Map<String, Object>> save(HttpServletRequest request, @RequestBody Map<String, String> body) {
        return ApiResponse.ok(configs.save(uid(request), body.get("baseUrl"), body.get("model"), body.get("apiKey")));
    }

    @PostMapping("/test")
    public ResponseEntity<ApiResponse<Map<String, Object>>> test(HttpServletRequest request,
                                                                 @RequestBody Map<String, String> body) {
        long userId = uid(request);
        int retry = limit.retryAfter(userId, true);
        if (retry > 0) {
            return ResponseEntity.status(429).header("Retry-After", Integer.toString(retry))
                    .body(ApiResponse.error(429, "连接测试太频繁，请稍后再试"));
        }
        return ResponseEntity.ok(ApiResponse.ok(
                gateway.testAccountConfig(userId, body.get("baseUrl"), body.get("model"), body.get("apiKey"))));
    }

    @DeleteMapping
    public ApiResponse<Void> delete(HttpServletRequest request) {
        configs.delete(uid(request));
        return ApiResponse.ok();
    }
}
