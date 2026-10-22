package com.javacourse.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 习题与提交记录仓储
 */
@Repository
public class CodeRepository {

    private final JdbcTemplate jdbc;

    public CodeRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ---------------- 习题 ----------------

    private static final String EXERCISE_SELECT =
            "SELECT e.id, e.lesson_id, e.slug, e.title, e.description, e.difficulty, e.language, "
                    + "e.starter_code, e.solution_code, e.test_cases, e.hint, e.sort_order, "
                    + "l.title AS lesson_title, l.slug AS lesson_slug "
                    + "FROM code_exercise e LEFT JOIN lesson l ON l.id = e.lesson_id ";

    private static Map<String, Object> mapExercise(java.sql.ResultSet rs) throws java.sql.SQLException {
        Map<String, Object> m = new HashMap<>();
        m.put("id", rs.getLong("id"));
        long lessonId = rs.getLong("lesson_id");
        m.put("lessonId", rs.wasNull() ? null : lessonId);
        m.put("slug", rs.getString("slug"));
        m.put("title", rs.getString("title"));
        m.put("description", rs.getString("description"));
        m.put("difficulty", rs.getString("difficulty"));
        m.put("language", rs.getString("language"));
        m.put("starterCode", rs.getString("starter_code"));
        m.put("solutionCode", rs.getString("solution_code"));
        m.put("testCases", rs.getString("test_cases"));
        m.put("hint", rs.getString("hint"));
        m.put("sortOrder", rs.getInt("sort_order"));
        m.put("lessonTitle", rs.getString("lesson_title"));
        m.put("lessonSlug", rs.getString("lesson_slug"));
        return m;
    }

    public List<Map<String, Object>> listExercises(Long lessonId) {
        if (lessonId == null) {
            return jdbc.query(EXERCISE_SELECT + "ORDER BY e.sort_order, e.id",
                    (rs, i) -> mapExercise(rs));
        }
        return jdbc.query(EXERCISE_SELECT + "WHERE e.lesson_id = ? ORDER BY e.sort_order, e.id",
                (rs, i) -> mapExercise(rs), lessonId);
    }

    public Map<String, Object> findExerciseBySlug(String slug) {
        List<Map<String, Object>> list = jdbc.query(
                EXERCISE_SELECT + "WHERE e.slug = ?", (rs, i) -> mapExercise(rs), slug);
        return list.isEmpty() ? null : list.get(0);
    }

    public Map<String, Object> findExerciseById(long id) {
        List<Map<String, Object>> list = jdbc.query(
                EXERCISE_SELECT + "WHERE e.id = ?", (rs, i) -> mapExercise(rs), id);
        return list.isEmpty() ? null : list.get(0);
    }

    /** 某课时的习题数量 */
    public int countByLesson(long lessonId) {
        Integer n = jdbc.queryForObject(
                "SELECT COUNT(*) FROM code_exercise WHERE lesson_id = ?", Integer.class, lessonId);
        return n == null ? 0 : n;
    }

    // ---------------- 提交记录 ----------------

    public void insertSubmission(long userId, Long exerciseId, String sourceCode, String status,
                                 String caseResults, String stdout, String stderr, String errorOutput,
                                 int passedCount, int totalCount, int durationMs) {
        jdbc.update(connection -> {
            java.sql.PreparedStatement ps = connection.prepareStatement(
                    "INSERT INTO code_submission (user_id, exercise_id, source_code, status, "
                            + "case_results, stdout, stderr, error_output, passed_count, total_count, duration_ms) "
                            + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    new String[]{"id"});
            if (userId > 0) {
                ps.setLong(1, userId);
            } else {
                ps.setNull(1, java.sql.Types.BIGINT);
            }
            if (exerciseId == null) {
                ps.setNull(2, java.sql.Types.BIGINT);
            } else {
                ps.setLong(2, exerciseId);
            }
            ps.setString(3, sourceCode);
            ps.setString(4, status);
            ps.setString(5, caseResults);
            ps.setString(6, stdout);
            ps.setString(7, stderr);
            ps.setString(8, errorOutput);
            ps.setInt(9, passedCount);
            ps.setInt(10, totalCount);
            ps.setInt(11, durationMs);
            return ps;
        });
    }

    public List<Map<String, Object>> listSubmissions(long userId, Long exerciseId) {
        if (exerciseId == null) {
            return jdbc.query(
                    "SELECT s.id, s.exercise_id, s.status, s.passed_count, s.total_count, "
                            + "s.duration_ms, s.created_at, e.title AS exercise_title, e.slug AS exercise_slug "
                            + "FROM code_submission s LEFT JOIN code_exercise e ON e.id = s.exercise_id "
                            + "WHERE s.user_id = ? ORDER BY s.id DESC LIMIT 50",
                    (rs, i) -> {
                        Map<String, Object> m = new HashMap<>();
                        m.put("id", rs.getLong("id"));
                        m.put("exerciseId", rs.getLong("exercise_id"));
                        m.put("status", rs.getString("status"));
                        m.put("passedCount", rs.getInt("passed_count"));
                        m.put("totalCount", rs.getInt("total_count"));
                        m.put("durationMs", rs.getInt("duration_ms"));
                        m.put("createdAt", rs.getTimestamp("created_at"));
                        m.put("exerciseTitle", rs.getString("exercise_title"));
                        m.put("exerciseSlug", rs.getString("exercise_slug"));
                        return m;
                    }, userId);
        }
        return jdbc.query(
                "SELECT s.id, s.exercise_id, s.status, s.passed_count, s.total_count, "
                        + "s.duration_ms, s.created_at, e.title AS exercise_title, e.slug AS exercise_slug "
                        + "FROM code_submission s LEFT JOIN code_exercise e ON e.id = s.exercise_id "
                        + "WHERE s.user_id = ? AND s.exercise_id = ? ORDER BY s.id DESC LIMIT 50",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", rs.getLong("id"));
                    m.put("exerciseId", rs.getLong("exercise_id"));
                    m.put("status", rs.getString("status"));
                    m.put("passedCount", rs.getInt("passed_count"));
                    m.put("totalCount", rs.getInt("total_count"));
                    m.put("durationMs", rs.getInt("duration_ms"));
                    m.put("createdAt", rs.getTimestamp("created_at"));
                    m.put("exerciseTitle", rs.getString("exercise_title"));
                    m.put("exerciseSlug", rs.getString("exercise_slug"));
                    return m;
                }, userId, exerciseId);
    }
}
