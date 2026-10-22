package com.javacourse.service;

import com.javacourse.repository.CourseRepository;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 课程内容服务：聚合课程 / 模块 / 课时 / 目录树
 */
@Service
public class CourseService {

    private final CourseRepository repo;

    public CourseService(CourseRepository repo) {
        this.repo = repo;
    }

    public List<Map<String, Object>> listCourses() {
        return repo.listCourses();
    }

    public Map<String, Object> getCourseDetail(String slug) {
        Map<String, Object> course = repo.findCourseBySlug(slug);
        if (course == null) {
            return null;
        }
        long courseId = (Long) course.get("id");
        List<Map<String, Object>> modules = repo.listModules(courseId);

        // 目录树：模块 -> 课时
        List<Map<String, Object>> tree = new ArrayList<>();
        for (Map<String, Object> mod : modules) {
            long moduleId = (Long) mod.get("id");
            List<Map<String, Object>> lessons = repo.listLessonsByModule(moduleId);
            Map<String, Object> node = new HashMap<>(mod);
            node.put("lessons", lessons);
            tree.add(node);
        }
        course.put("modules", tree);
        return course;
    }

    public List<Map<String, Object>> listModules() {
        return repo.listAllModules();
    }

    public Map<String, Object> getLesson(String slug) {
        // findLessonBySlug 不返回 content 正文，必须走 findLessonDetail
        Map<String, Object> brief = repo.findLessonBySlug(slug);
        if (brief == null) {
            return null;
        }
        long id = (Long) brief.get("id");
        Map<String, Object> lesson = repo.findLessonDetail(id);
        if (lesson == null) {
            return brief;
        }
        repo.incrementView(id);
        lesson.put("viewCount", ((Number) brief.getOrDefault("viewCount", 0)).longValue() + 1);
        lesson.put("snippets", repo.listSnippets(id));
        lesson.put("knowledge", repo.listKnowledgeOfLesson(id));
        // 上下课时导航
        List<Map<String, Object>> siblings = repo.listLessonsByModule((Long) lesson.get("moduleId"));
        int idx = -1;
        for (int i = 0; i < siblings.size(); i++) {
            if (((Long) siblings.get(i).get("id")).longValue() == id) {
                idx = i;
                break;
            }
        }
        if (idx > 0) {
            lesson.put("prev", siblings.get(idx - 1));
        }
        if (idx >= 0 && idx < siblings.size() - 1) {
            lesson.put("next", siblings.get(idx + 1));
        }
        return lesson;
    }

    public List<Map<String, Object>> listQa() {
        return repo.listQa();
    }
}
