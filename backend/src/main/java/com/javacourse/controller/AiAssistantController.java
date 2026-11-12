package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.service.AiAssistantService;
import com.javacourse.service.AssistantRequestLimit;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * AI 助教（鲸鲸）接口
 */
@RestController
public class AiAssistantController {

    private static final int MAX_QUESTION_LENGTH = 6000;
    private final AiAssistantService aiService;
    private final AssistantRequestLimit limit;
    private final JdbcTemplate jdbc;

    public AiAssistantController(AiAssistantService aiService, AssistantRequestLimit limit, JdbcTemplate jdbc) {
        this.aiService = aiService;
        this.limit = limit;
        this.jdbc = jdbc;
    }

    public record AskRequest(String question, String lessonSlug) {}

    /** 助教形象元信息 */
    @GetMapping("/ai/agent")
    public ApiResponse<Map<String, Object>> agent() {
        return ApiResponse.ok(aiService.agentProfile());
    }

    @PostMapping("/ai/ask")
    public ResponseEntity<ApiResponse<Map<String, Object>>> ask(@RequestBody AskRequest body, HttpServletRequest http) {
        return ask(body, http, false);
    }

    @PostMapping("/ai/ask/local")
    public ResponseEntity<ApiResponse<Map<String, Object>>> askLocal(@RequestBody AskRequest body, HttpServletRequest http) {
        return ask(body, http, true);
    }

    private ResponseEntity<ApiResponse<Map<String, Object>>> ask(AskRequest body, HttpServletRequest http, boolean localOnly) {
        String question = body.question();
        if (question == null || question.isBlank()) {
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "问题不能为空"));
        }
        if (question.length() > MAX_QUESTION_LENGTH) {
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "问题过长，请保留相关描述和最小代码片段"));
        }
        String lessonSlug = body.lessonSlug();
        if (lessonSlug != null && (lessonSlug.length() > 80 || !lessonSlug.matches("[a-z0-9]+(?:-[a-z0-9]+)*"))) {
            return ResponseEntity.badRequest().body(ApiResponse.error(400, "课时标识无效"));
        }
        long userId = (Long) http.getAttribute("userId");
        int retry = limit.retryAfter(userId, false);
        if (retry > 0) {
            return ResponseEntity.status(429).header("Retry-After", Integer.toString(retry))
                    .body(ApiResponse.error(429, "提问太频繁，请稍后再试"));
        }
        return ResponseEntity.ok(ApiResponse.ok(aiService.ask(userId, question.strip(), localOnly, lessonSlug)));
    }

    /** Legacy sessions were persisted by older releases; deleting the session cascades to its messages. */
    @DeleteMapping("/ai/history")
    public ApiResponse<Map<String, Integer>> clearLegacyHistory(HttpServletRequest http) {
        long userId = (Long) http.getAttribute("userId");
        int removed = jdbc.update("DELETE FROM ai_chat_session WHERE user_id = ? AND agent_key = 'whale'", userId);
        return ApiResponse.ok(Map.of("removed", removed));
    }

    /** 助教接口可用状态。 */
    @GetMapping("/ai/health")
    public ApiResponse<Map<String, Object>> health() {
        return ApiResponse.ok(aiService.aiHealth());
    }
}
