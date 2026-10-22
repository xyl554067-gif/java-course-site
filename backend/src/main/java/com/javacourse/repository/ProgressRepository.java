package com.javacourse.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 学习进度与收藏仓储
 */
@Repository
public class ProgressRepository {

    private final JdbcTemplate jdbc;

    public ProgressRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final RowMapper<Map<String, Object>> PROGRESS_MAPPER = (rs, i) -> {
        Map<String, Object> m = new HashMap<>();
        m.put("lessonId", rs.getLong("lesson_id"));
        m.put("slug", rs.getString("slug"));
        m.put("title", rs.getString("title"));
        m.put("moduleTitle", rs.getString("module_title"));
        m.put("sortOrder", rs.getInt("sort_order"));
        m.put("progressPct", rs.getInt("progress_pct"));
        m.put("completed", rs.getInt("completed") == 1);
        m.put("lastSeconds", rs.getInt("last_seconds"));
        m.put("updatedAt", rs.getTimestamp("updated_at"));
        return m;
    };

    private static final String SELECT_JOIN =
            "SELECT lp.lesson_id, lp.progress_pct, lp.completed, lp.last_seconds, lp.updated_at, "
                    + "l.title, l.slug, l.sort_order, m.title AS module_title "
                    + "FROM learning_progress lp "
                    + "JOIN lesson l ON l.id = lp.lesson_id "
                    + "JOIN course_module m ON m.id = l.module_id ";

    /** 某用户全部进度记录 */
    public List<Map<String, Object>> listByUser(long userId) {
        return jdbc.query(SELECT_JOIN + "WHERE lp.user_id = ? ORDER BY lp.updated_at DESC",
                PROGRESS_MAPPER, userId);
    }

    /** 单个课时的进度，不存在返回 null */
    public Map<String, Object> findOne(long userId, long lessonId) {
        List<Map<String, Object>> list = jdbc.query(
                SELECT_JOIN + "WHERE lp.user_id = ? AND lp.lesson_id = ?",
                PROGRESS_MAPPER, userId, lessonId);
        return list.isEmpty() ? null : list.get(0);
    }

    /**
     * Upsert 进度。KingBase V8 支持 ON CONFLICT，
     * 用它替代「先查再插/改」避免竞态与多余往返。
     */
    public void upsert(long userId, long lessonId, int progressPct,
                       boolean completed, int lastSeconds) {
        jdbc.update(
                "INSERT INTO learning_progress (user_id, lesson_id, progress_pct, completed, last_seconds, updated_at) "
                        + "VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP) "
                        + "ON CONFLICT (user_id, lesson_id) DO UPDATE SET "
                        + "progress_pct = EXCLUDED.progress_pct, "
                        + "completed = EXCLUDED.completed, "
                        + "last_seconds = EXCLUDED.last_seconds, "
                        + "updated_at = CURRENT_TIMESTAMP",
                userId, lessonId, Math.max(0, Math.min(100, progressPct)),
                completed ? 1 : 0, Math.max(0, lastSeconds));
    }

    /** 标记完成/取消完成，保留进度百分比 */
    public void markCompleted(long userId, long lessonId, boolean completed) {
        int pct = completed ? 100 : 0;
        jdbc.update(
                "INSERT INTO learning_progress (user_id, lesson_id, progress_pct, completed, last_seconds, updated_at) "
                        + "VALUES (?, ?, ?, ?, 0, CURRENT_TIMESTAMP) "
                        + "ON CONFLICT (user_id, lesson_id) DO UPDATE SET "
                        + "progress_pct = EXCLUDED.progress_pct, "
                        + "completed = EXCLUDED.completed, "
                        + "updated_at = CURRENT_TIMESTAMP",
                userId, lessonId, pct, completed ? 1 : 0);
    }

    /** 学习总览：完成数、在学数、总课时 */
    public Map<String, Object> summary(long userId, long totalLessons) {
        Map<String, Object> m = new HashMap<>();
        m.put("totalLessons", totalLessons);
        m.put("completed", jdbc.queryForObject(
                "SELECT COUNT(*) FROM learning_progress WHERE user_id = ? AND completed = 1",
                Integer.class, userId));
        m.put("inProgress", jdbc.queryForObject(
                "SELECT COUNT(*) FROM learning_progress WHERE user_id = ? AND completed = 0 AND progress_pct > 0",
                Integer.class, userId));
        m.put("started", jdbc.queryForObject(
                "SELECT COUNT(*) FROM learning_progress WHERE user_id = ? AND progress_pct > 0",
                Integer.class, userId));
        m.put("totalSeconds", jdbc.queryForObject(
                "SELECT COALESCE(SUM(last_seconds), 0) FROM learning_progress WHERE user_id = ?",
                Integer.class, userId));
        m.put("favoriteCount", jdbc.queryForObject(
                "SELECT COUNT(*) FROM user_favorite WHERE user_id = ?",
                Integer.class, userId));
        return m;
    }

    // ---------------- 收藏 ----------------

    /** 返回 true 表示收藏成功，false 表示已收藏（幂等） */
    public boolean addFavorite(long userId, long lessonId) {
        return jdbc.update(
                "INSERT INTO user_favorite (user_id, lesson_id) VALUES (?, ?) "
                        + "ON CONFLICT (user_id, lesson_id) DO NOTHING",
                userId, lessonId) > 0;
    }

    public boolean removeFavorite(long userId, long lessonId) {
        return jdbc.update(
                "DELETE FROM user_favorite WHERE user_id = ? AND lesson_id = ?",
                userId, lessonId) > 0;
    }

    public boolean isFavorite(long userId, long lessonId) {
        Integer n = jdbc.queryForObject(
                "SELECT COUNT(*) FROM user_favorite WHERE user_id = ? AND lesson_id = ?",
                Integer.class, userId, lessonId);
        return n != null && n > 0;
    }

    public List<Map<String, Object>> listFavorites(long userId) {
        return jdbc.query(
                "SELECT f.lesson_id AS lesson_id, l.title AS title, l.slug AS slug, "
                        + "l.summary AS summary, m.title AS module_title, "
                        + "f.created_at AS created_at "
                        + "FROM user_favorite f "
                        + "JOIN lesson l ON l.id = f.lesson_id "
                        + "JOIN course_module m ON m.id = l.module_id "
                        + "WHERE f.user_id = ? ORDER BY f.created_at DESC",
                (rs, i) -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("lessonId", rs.getLong("lesson_id"));
                    m.put("title", rs.getString("title"));
                    m.put("slug", rs.getString("slug"));
                    m.put("summary", rs.getString("summary"));
                    m.put("moduleTitle", rs.getString("module_title"));
                    m.put("createdAt", rs.getTimestamp("created_at"));
                    return m;
                }, userId);
    }

    /** 已收藏的课时 id 集合，前端渲染星标时批量取 */
    public List<Long> favoriteIds(long userId) {
        return jdbc.queryForList(
                "SELECT lesson_id FROM user_favorite WHERE user_id = ?",
                Long.class, userId);
    }

    /** 已完成的课时 id 集合 */
    public List<Long> completedIds(long userId) {
        return jdbc.queryForList(
                "SELECT lesson_id FROM learning_progress WHERE user_id = ? AND completed = 1",
                Long.class, userId);
    }
}