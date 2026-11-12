package com.javacourse.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class LearningVideoRepository {
    private static final String FROM = """
            FROM lesson_video lv
            JOIN learning_video v ON v.id = lv.video_id
            JOIN lesson l ON l.id = lv.lesson_id
            JOIN course_module m ON m.id = l.module_id
            JOIN course c ON c.id = m.course_id
            """;
    private static final String SELECT = """
            SELECT lv.id, v.bvid, v.source_url, v.title, v.uploader, lv.part_number,
                   lv.start_seconds, lv.label, lv.recommendation, lv.sort_order,
                   l.id AS lesson_id, l.slug AS lesson_slug, l.title AS lesson_title,
                   c.slug AS course_slug, c.title AS course_title
            """;
    private final JdbcTemplate jdbc;

    public LearningVideoRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record Video(long id, String bvid, String sourceUrl, String title, String uploader,
                        int partNumber, int startSeconds, String label, String recommendation,
                        int sortOrder, long lessonId, String lessonSlug, String lessonTitle,
                        String courseSlug, String courseTitle) {}

    public List<Video> catalog() {
        return query("""
                WHERE c.status = 'PUBLISHED'
                ORDER BY c.sort_order, c.id, m.sort_order, m.id, l.sort_order, l.id, lv.sort_order, lv.id
                """);
    }

    public List<Video> forLesson(long lessonId) {
        return query("WHERE l.id = ? AND c.status = 'PUBLISHED' ORDER BY lv.sort_order, lv.id", lessonId);
    }

    public List<Long> lessonIdsForCourse(long courseId) {
        return jdbc.queryForList("SELECT DISTINCT l.id " + FROM
                + "WHERE c.id = ? AND c.status = 'PUBLISHED'", Long.class, courseId);
    }

    private List<Video> query(String clause, Object... args) {
        return jdbc.query(SELECT + FROM + clause, (rs, row) -> new Video(
                rs.getLong("id"), rs.getString("bvid"), rs.getString("source_url"),
                rs.getString("title"), rs.getString("uploader"), rs.getInt("part_number"),
                rs.getInt("start_seconds"), rs.getString("label"), rs.getString("recommendation"),
                rs.getInt("sort_order"), rs.getLong("lesson_id"), rs.getString("lesson_slug"),
                rs.getString("lesson_title"), rs.getString("course_slug"), rs.getString("course_title")), args);
    }
}
