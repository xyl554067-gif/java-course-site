package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.service.AiAssistantService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * AI 助教（鲸鲸）接口
 */
@RestController
public class AiAssistantController {

    private final AiAssistantService aiService;

    public AiAssistantController(AiAssistantService aiService) {
        this.aiService = aiService;
    }

    /** 助教形象元信息 */
    @GetMapping("/ai/agent")
    public ApiResponse<Map<String, Object>> agent() {
        return ApiResponse.ok(aiService.agentProfile());
    }

    @PostMapping("/ai/ask")
    public ApiResponse<Map<String, Object>> ask(@RequestBody Map<String, String> body,
                                                HttpServletRequest http) {
        String question = body.get("question");
        if (question == null || question.isBlank()) {
            return ApiResponse.error(400, "问题不能为空");
        }
        Object uid = http.getAttribute("userId");
        long userId = uid instanceof Long ? (Long) uid : 0L;
        return ApiResponse.ok(aiService.ask(userId, question.trim(), body.get("sessionTitle")));
    }

    /**
     * AI 通道诊断：让前端能显示「当前跑在哪个通道上」，用户在提问前就知道
     * 这次回答是大模型生成的、还是走了本地兜底。
     */
    @GetMapping("/ai/health")
    public ApiResponse<Map<String, Object>> health() {
        return ApiResponse.ok(aiService.aiHealth());
    }
}
