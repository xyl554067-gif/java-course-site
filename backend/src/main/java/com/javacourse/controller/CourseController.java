package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.service.CourseService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 课程内容接口
 */
@RestController
public class CourseController {

    private final CourseService courseService;

    public CourseController(CourseService courseService) {
        this.courseService = courseService;
    }

    @GetMapping("/course/list")
    public ApiResponse<List<Map<String, Object>>> listCourses() {
        return ApiResponse.ok(courseService.listCourses());
    }

    @GetMapping("/course/{slug}")
    public ApiResponse<Map<String, Object>> courseDetail(@PathVariable String slug) {
        Map<String, Object> c = courseService.getCourseDetail(slug);
        return c == null ? ApiResponse.error(404, "课程不存在") : ApiResponse.ok(c);
    }

    @GetMapping("/modules")
    public ApiResponse<List<Map<String, Object>>> modules() {
        return ApiResponse.ok(courseService.listModules());
    }

    @GetMapping("/lesson/{slug}")
    public ApiResponse<Map<String, Object>> lesson(@PathVariable String slug) {
        Map<String, Object> l = courseService.getLesson(slug);
        return l == null ? ApiResponse.error(404, "课时不存在") : ApiResponse.ok(l);
    }

    @GetMapping("/qa/list")
    public ApiResponse<List<Map<String, Object>>> qa() {
        return ApiResponse.ok(courseService.listQa());
    }
}
