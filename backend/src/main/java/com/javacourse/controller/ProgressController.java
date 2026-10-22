package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.service.ProgressService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 学习进度与收藏接口（全部需要登录）
 */
@RestController
@RequestMapping("/progress")
public class ProgressController {

    private final ProgressService service;

    public ProgressController(ProgressService service) {
        this.service = service;
    }

    private static long uid(HttpServletRequest req) {
        Object v = req.getAttribute("userId");
        return v == null ? 0L : (Long) v;
    }

    /** DTO 内部类，避免单独建文件 */
    public static class SaveRequest {
        @Min(0) @Max(100)
        public Integer progressPct;
        /** 本次会话累计已学秒数 */
        @Min(0)
        public Integer lastSeconds;
        /** 相对上次上报新增加的秒数，用于累加总学习时长 */
        @Min(0)
        public Integer deltaSeconds;
        /** 会话标识：同一会话重复上报只计一次学习次数 */
        public String sessionKey;
    }

    public static class MarkRequest {
        public Boolean completed;
    }

    /** 总览：完成数、在学数、总进度百分比 */
    @GetMapping("/summary")
    public ApiResponse<Map<String, Object>> summary(HttpServletRequest req) {
        return ApiResponse.ok(service.summary(uid(req)));
    }

    /** 全部进度 + 收藏列表 */
    @GetMapping
    public ApiResponse<Map<String, Object>> list(HttpServletRequest req) {
        return ApiResponse.ok(service.list(uid(req)));
    }

    /** 批量取收藏与完成标记，供课程目录打标 */
    @GetMapping("/marks")
    public ApiResponse<Map<String, Object>> marks(HttpServletRequest req) {
        return ApiResponse.ok(service.marks(uid(req)));
    }

    /** 单课时进度 */
    @GetMapping("/lesson/{lessonId}")
    public ApiResponse<Map<String, Object>> one(HttpServletRequest req,
@PathVariable long lessonId) {
        return ApiResponse.ok(service.get(uid(req), lessonId));
    }

    /** 保存进度（前端滚动/心跳调用） */
    @PutMapping("/lesson/{lessonId}")
    public ApiResponse<Map<String, Object>> save(HttpServletRequest req,
                                                 @PathVariable long lessonId,
                                                 @Valid @RequestBody SaveRequest body) {
        return ApiResponse.ok(service.save(uid(req), lessonId,
                body.progressPct, body.lastSeconds, body.deltaSeconds, body.sessionKey));
    }

    /** 标记完成 / 取消完成 */
    @PostMapping("/lesson/{lessonId}/complete")
    public ApiResponse<Map<String, Object>> complete(HttpServletRequest req,
                                                     @PathVariable long lessonId,
                                                     @RequestParam(defaultValue = "true") boolean completed) {
        return ApiResponse.ok(service.mark(uid(req), lessonId, completed));
    }

    /** 收藏开关，返回切换后的状态 */
    @PostMapping("/lesson/{lessonId}/favorite")
    public ApiResponse<Map<String, Object>> favorite(HttpServletRequest req,
                                                      @PathVariable long lessonId) {
        return ApiResponse.ok(service.toggleFavorite(uid(req), lessonId));
    }
}