package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.service.CourseImportService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/ai/courses")
public class CourseImportController {
    private final CourseImportService service;
    public CourseImportController(CourseImportService service) { this.service = service; }
    private long uid(HttpServletRequest req) { return (Long) req.getAttribute("userId"); }

    @PostMapping("/import/file")
    public ApiResponse<Map<String,Object>> file(HttpServletRequest req, @RequestParam("file") MultipartFile file) {
        return ApiResponse.ok(service.importFile(uid(req), file));
    }
    @PostMapping("/import/url")
    public ApiResponse<Map<String,Object>> url(HttpServletRequest req, @RequestBody Map<String,String> body) {
        return ApiResponse.ok(service.importUrl(uid(req), body.get("url")));
    }
    @GetMapping
    public ApiResponse<?> mine(HttpServletRequest req) { return ApiResponse.ok(service.listMine(uid(req))); }
    @GetMapping("/{id}")
    public ApiResponse<Map<String,Object>> get(HttpServletRequest req, @PathVariable long id) { return ApiResponse.ok(service.getMine(uid(req),id)); }
    @PutMapping("/{id}")
    public ApiResponse<Map<String,Object>> save(HttpServletRequest req, @PathVariable long id, @RequestBody Map<String,String> body) {
        return ApiResponse.ok(service.saveDraft(uid(req),id,body.get("course")));
    }
    @PostMapping("/{id}/publish")
    public ApiResponse<Map<String,Object>> publish(HttpServletRequest req, @PathVariable long id) { return ApiResponse.ok(service.publish(uid(req),id)); }
    @PostMapping("/{id}/share")
    public ApiResponse<Map<String,Object>> share(HttpServletRequest req, @PathVariable long id) { return ApiResponse.ok(service.share(uid(req),id)); }
    @DeleteMapping("/{id}/share")
    public ApiResponse<Void> revoke(HttpServletRequest req, @PathVariable long id) { service.revoke(uid(req),id); return ApiResponse.ok(); }
    @GetMapping("/shared/{token}")
    public ApiResponse<Map<String,Object>> shared(@PathVariable String token) { return ApiResponse.ok(service.shared(token)); }
}
