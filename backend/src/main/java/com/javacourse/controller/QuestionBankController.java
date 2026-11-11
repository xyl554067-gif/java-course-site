package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.service.QuestionBankService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/qa")
public class QuestionBankController {
    private final QuestionBankService service;

    public QuestionBankController(QuestionBankService service) { this.service = service; }

    private long uid(HttpServletRequest request) { return (Long) request.getAttribute("userId"); }

    @GetMapping("/list")
    public ApiResponse<List<Map<String, Object>>> list(HttpServletRequest request) {
        return ApiResponse.ok(service.list(uid(request)));
    }

    @GetMapping("/lessons")
    public ApiResponse<List<Map<String, Object>>> lessons() {
        return ApiResponse.ok(service.lessons());
    }

    @PostMapping("/items")
    public ApiResponse<Map<String, Object>> create(HttpServletRequest request, @RequestBody Map<String, Object> body) {
        return ApiResponse.ok(service.create(uid(request), body));
    }

    @PutMapping("/items/{id}")
    public ApiResponse<Map<String, Object>> update(HttpServletRequest request, @PathVariable long id, @RequestBody Map<String, Object> body) {
        return ApiResponse.ok(service.update(uid(request), id, body));
    }

    @DeleteMapping("/items/{id}")
    public ApiResponse<Void> delete(HttpServletRequest request, @PathVariable long id) {
        service.delete(uid(request), id);
        return ApiResponse.ok();
    }

    @PostMapping("/import")
    public ApiResponse<Map<String, Object>> importItems(HttpServletRequest request, @RequestBody Map<String, Object> body) {
        Object raw = body.get("items");
        if (!(raw instanceof List<?> items)) throw new IllegalArgumentException("导入数据缺少 items 列表");
        return ApiResponse.ok(service.importItems(uid(request), items));
    }
}
