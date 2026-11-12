package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.repository.LearningVideoRepository;
import com.javacourse.repository.LearningVideoRepository.Video;
import com.javacourse.service.LearningVideoService;
import com.javacourse.service.LearningVideoService.VideoInput;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/learning-videos")
public class LearningVideoController {
    private final LearningVideoRepository videos;
    private final LearningVideoService service;

    public LearningVideoController(LearningVideoRepository videos, LearningVideoService service) {
        this.videos = videos;
        this.service = service;
    }

    @GetMapping
    public ApiResponse<List<Video>> list() {
        return ApiResponse.ok(videos.catalog());
    }

    @PostMapping
    public ResponseEntity<ApiResponse<Void>> create(@RequestAttribute("role") String role,
                                                    @RequestBody VideoInput input) {
        if (!isAdmin(role)) return forbidden();
        service.save(null, input);
        return ResponseEntity.ok(ApiResponse.ok());
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> update(@RequestAttribute("role") String role, @PathVariable long id,
                                                    @RequestBody VideoInput input) {
        if (!isAdmin(role)) return forbidden();
        service.save(id, input);
        return ResponseEntity.ok(ApiResponse.ok());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> remove(@RequestAttribute("role") String role, @PathVariable long id) {
        if (!isAdmin(role)) return forbidden();
        service.remove(id);
        return ResponseEntity.ok(ApiResponse.ok());
    }

    private static boolean isAdmin(String role) {
        return "admin".equalsIgnoreCase(role);
    }

    private static ResponseEntity<ApiResponse<Void>> forbidden() {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiResponse.error(403, "仅管理员可维护学习视频"));
    }
}
