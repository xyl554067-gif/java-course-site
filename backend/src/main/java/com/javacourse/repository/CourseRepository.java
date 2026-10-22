package com.javacourse.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 课程内容仓储：课程 / 模块 / 课时 / 代码片段 / 知识点 / 问答
 */
@Repository
public class CourseRepository {

    private final JdbcTemplate jdbc;

    public CourseRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ---------------- 课程 ----------------

    public List<Map<String, Object>> listCourses() {
        return jdbc.query(
                "SELECT id, slug, title, subtitle, description, cover_image, instructor, version, "
                        + "difficulty, status, sort_order, total_lessons, created_at "
                        + "FROM course WHERE status = 'PUBLISHED' ORDER BY sort_order, id",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("slug", rs.getString("slug"));
                    m.put("title", rs.getString("title"));
                    m.put("subtitle", rs.getString("subtitle"));
                    m.put("description", rs.getString("description"));
                    m.put("coverImage", rs.getString("cover_image"));
                    m.put("instructor", rs.getString("instructor"));
                    m.put("version", rs.getString("version"));
                    m.put("difficulty", rs.getString("difficulty"));
                    m.put("status", rs.getString("status"));
                    m.put("sortOrder", rs.getInt("sort_order"));
                    m.put("totalLessons", rs.getInt("total_lessons"));
                    m.put("createdAt", rs.getTimestamp("created_at"));
                    return m;
                });
    }

    public Map<String, Object> findCourseBySlug(String slug) {
        List<Map<String, Object>> list = jdbc.query(
                "SELECT id, slug, title, subtitle, description, cover_image, instructor, version, "
                        + "difficulty, status, sort_order, total_lessons FROM course WHERE slug = ?",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("slug", rs.getString("slug"));
                    m.put("title", rs.getString("title"));
                    m.put("subtitle", rs.getString("subtitle"));
                    m.put("description", rs.getString("description"));
                    m.put("coverImage", rs.getString("cover_image"));
                    m.put("instructor", rs.getString("instructor"));
                    m.put("version", rs.getString("version"));
                    m.put("difficulty", rs.getString("difficulty"));
                    m.put("status", rs.getString("status"));
                    m.put("sortOrder", rs.getInt("sort_order"));
                    m.put("totalLessons", rs.getInt("total_lessons"));
                    return m;
                }, slug);
        return list.isEmpty() ? null : list.get(0);
    }

    // ---------------- 模块 ----------------

    public List<Map<String, Object>> listModules(long courseId) {
        return jdbc.query(
                "SELECT id, course_id, title, summary, icon, sort_order, lesson_count "
                        + "FROM course_module WHERE course_id = ? ORDER BY sort_order, id",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("courseId", rs.getLong("course_id"));
                    m.put("title", rs.getString("title"));
                    m.put("summary", rs.getString("summary"));
                    m.put("icon", rs.getString("icon"));
                    m.put("sortOrder", rs.getInt("sort_order"));
                    m.put("lessonCount", rs.getInt("lesson_count"));
                    return m;
                }, courseId);
    }

    public List<Map<String, Object>> listAllModules() {
        return jdbc.query(
                "SELECT m.id, m.course_id, m.title, m.summary, m.icon, m.sort_order, m.lesson_count, c.title AS course_title "
                        + "FROM course_module m JOIN course c ON c.id = m.course_id "
                        + "ORDER BY c.sort_order, m.sort_order, m.id",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("courseId", rs.getLong("course_id"));
                    m.put("title", rs.getString("title"));
                    m.put("summary", rs.getString("summary"));
                    m.put("icon", rs.getString("icon"));
                    m.put("sortOrder", rs.getInt("sort_order"));
                    m.put("lessonCount", rs.getInt("lesson_count"));
                    m.put("courseTitle", rs.getString("course_title"));
                    return m;
                });
    }

    // ---------------- 课时 ----------------

    private static final RowMapper<Map<String, Object>> LESSON_MAPPER = (rs, i) -> {
        Map<String, Object> m = new HashMap<>();
        m.put("id", rs.getLong("id"));
        m.put("moduleId", rs.getLong("module_id"));
        m.put("moduleTitle", rs.getString("module_title"));
        m.put("title", rs.getString("title"));
        m.put("slug", rs.getString("slug"));
        m.put("summary", rs.getString("summary"));
        m.put("durationMin", rs.getInt("duration_min"));
        m.put("difficulty", rs.getString("difficulty"));
        m.put("sortOrder", rs.getInt("sort_order"));
        m.put("isPreview", rs.getInt("is_preview") == 1);
        m.put("viewCount", rs.getInt("view_count"));
        return m;
    };

    private static final String LESSON_SELECT =
            "SELECT l.id, l.module_id, l.title, l.slug, l.summary, l.duration_min, l.difficulty, "
                    + "l.sort_order, l.is_preview, l.view_count, m.title AS module_title "
                    + "FROM lesson l JOIN course_module m ON m.id = l.module_id ";

    public List<Map<String, Object>> listLessonsByModule(long moduleId) {
        return jdbc.query(LESSON_SELECT + "WHERE l.module_id = ? ORDER BY l.sort_order, l.id",
                LESSON_MAPPER, moduleId);
    }

    public List<Map<String, Object>> listAllLessons() {
        return jdbc.query(LESSON_SELECT + "ORDER BY m.sort_order, l.sort_order, l.id", LESSON_MAPPER);
    }

    public Map<String, Object> findLessonBySlug(String slug) {
        List<Map<String, Object>> list = jdbc.query(
                LESSON_SELECT + "WHERE l.slug = ?", LESSON_MAPPER, slug);
        return list.isEmpty() ? null : list.get(0);
    }

    public Map<String, Object> findLessonDetail(long lessonId) {
        List<Map<String, Object>> list = jdbc.query(
                "SELECT l.id, l.module_id, l.title, l.slug, l.summary, l.content, l.content_html, "
                        + "l.duration_min, l.difficulty, l.sort_order, l.is_preview, l.view_count, "
                        + "m.title AS module_title, m.course_id "
                        + "FROM lesson l JOIN course_module m ON m.id = l.module_id WHERE l.id = ?",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("moduleId", rs.getLong("module_id"));
                    m.put("moduleTitle", rs.getString("module_title"));
                    m.put("courseId", rs.getLong("course_id"));
                    m.put("title", rs.getString("title"));
                    m.put("slug", rs.getString("slug"));
                    m.put("summary", rs.getString("summary"));
                    m.put("content", rs.getString("content"));
                    m.put("contentHtml", rs.getString("content_html"));
                    m.put("durationMin", rs.getInt("duration_min"));
                    m.put("difficulty", rs.getString("difficulty"));
                    m.put("sortOrder", rs.getInt("sort_order"));
                    m.put("isPreview", rs.getInt("is_preview") == 1);
                    m.put("viewCount", rs.getInt("view_count"));
                    return m;
                }, lessonId);
        return list.isEmpty() ? null : list.get(0);
    }

    public void incrementView(long lessonId) {
        jdbc.update("UPDATE lesson SET view_count = view_count + 1 WHERE id = ?", lessonId);
    }

    // ---------------- 代码片段 ----------------

    public List<Map<String, Object>> listSnippets(long lessonId) {
        return jdbc.query(
                "SELECT id, lesson_id, language, title, code_text, explanation, sort_order "
                        + "FROM code_snippet WHERE lesson_id = ? ORDER BY sort_order, id",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("lessonId", rs.getLong("lesson_id"));
                    m.put("language", rs.getString("language"));
                    m.put("title", rs.getString("title"));
                    m.put("code", rs.getString("code_text"));
                    m.put("explanation", rs.getString("explanation"));
                    m.put("sortOrder", rs.getInt("sort_order"));
                    return m;
                }, lessonId);
    }

    // ---------------- 知识点 ----------------

    public List<Map<String, Object>> listKnowledgeOfLesson(long lessonId) {
        return jdbc.query(
                "SELECT k.id, k.name, k.category, k.description FROM knowledge_point k "
                        + "JOIN lesson_knowledge lk ON lk.kp_id = k.id WHERE lk.lesson_id = ? ORDER BY k.id",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("name", rs.getString("name"));
                    m.put("category", rs.getString("category"));
                    m.put("description", rs.getString("description"));
                    return m;
                }, lessonId);
    }

    public List<Map<String, Object>> listAllKnowledge() {
        return jdbc.query(
                "SELECT id, name, category, description FROM knowledge_point ORDER BY category, id",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("name", rs.getString("name"));
                    m.put("category", rs.getString("category"));
                    m.put("description", rs.getString("description"));
                    return m;
                });
    }

    // ---------------- 问答 ----------------

    public List<Map<String, Object>> listQa() {
        return jdbc.query(
                "SELECT id, lesson_id, question, answer_text, options_json, answer_key, qa_type, difficulty "
                        + "FROM qa_item ORDER BY id",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("lessonId", rs.getObject("lesson_id") == null ? null : rs.getLong("lesson_id"));
                    m.put("question", rs.getString("question"));
                    m.put("answer", rs.getString("answer_text"));
                    m.put("options", rs.getString("options_json"));
                    m.put("answerKey", rs.getString("answer_key"));
                    m.put("qaType", rs.getString("qa_type"));
                    m.put("difficulty", rs.getString("difficulty"));
                    return m;
                });
    }

    // ---------------- 搜索索引 ----------------

    /** 分词可能上百个（中文单字+双字），限制参与 SQL 匹配的 token 数，避免谓词爆炸 */
    private static List<String> capTokens(List<String> tokens, String keyword) {
        List<String> out = new ArrayList<>();
        if (tokens == null) {
            return out;
        }
        for (String t : tokens) {
            if (t == null || t.isBlank()) {
                continue;
            }
            out.add(t);
            if (out.size() >= 12) {
                break;
            }
        }
        return out;
    }

    /**
     * 搜索索引检索：整词 + 分词 OR 匹配。
     * 中英混排（如「int和long有什么区别」）整串 LIKE 必然落空，必须靠分词兜底。
     */
    public List<Map<String, Object>> searchIndex(String keyword, List<String> tokens, int limit) {
        String like = "%" + keyword + "%";
        List<Object> args = new ArrayList<>();
        StringBuilder where = new StringBuilder(
                "WHERE title LIKE ? OR body_text LIKE ? OR tokens LIKE ?");
        args.add(like);
        args.add(like);
        args.add(like);
        for (String t : capTokens(tokens, keyword)) {
            if (t.equalsIgnoreCase(keyword)) {
                continue;
            }
            where.append(" OR title LIKE ? OR body_text LIKE ? OR tokens LIKE ?");
            String tk = "%" + t + "%";
            args.add(tk);
            args.add(tk);
            args.add(tk);
        }
        args.add(like);
        args.add(limit);
        return jdbc.query(
                "SELECT id, target_type, target_id, title, body_text, ref_url FROM search_index "
                        + where
                        + " ORDER BY CASE WHEN title LIKE ? THEN 0 ELSE 1 END, id LIMIT ?",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("targetType", rs.getString("target_type"));
                    m.put("targetId", rs.getLong("target_id"));
                    m.put("title", rs.getString("title"));
                    m.put("body", rs.getString("body_text"));
                    m.put("refUrl", rs.getString("ref_url"));
                    return m;
                }, args.toArray());
    }

    /** 取课程内容片段，作为 AI 回答的上下文 */
    public List<Map<String, Object>> searchContext(String keyword, List<String> tokens, int limit) {
        String like = "%" + keyword + "%";
        List<Object> args = new ArrayList<>();
        StringBuilder where = new StringBuilder(
                "WHERE l.title LIKE ? OR l.summary LIKE ? OR l.content LIKE ?");
        args.add(like);
        args.add(like);
        args.add(like);
        for (String t : capTokens(tokens, keyword)) {
            if (t.equalsIgnoreCase(keyword)) {
                continue;
            }
            where.append(" OR l.title LIKE ? OR l.summary LIKE ? OR l.content LIKE ?");
            String tk = "%" + t + "%";
            args.add(tk);
            args.add(tk);
            args.add(tk);
        }
        args.add(limit);
        List<Map<String, Object>> out = new ArrayList<>();
        jdbc.query(
                "SELECT l.id, l.title, l.slug, l.summary, l.content FROM lesson l "
                        + where
                        + " ORDER BY l.sort_order LIMIT ?",
                rs -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("title", rs.getString("title"));
                    m.put("slug", rs.getString("slug"));
                    m.put("summary", rs.getString("summary"));
                    m.put("content", rs.getString("content"));
                    out.add(m);
                }, args.toArray());
        return out;
    }
}
