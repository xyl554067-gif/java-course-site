package com.javacourse.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@Order(Ordered.LOWEST_PRECEDENCE)
class LessonProseUpgrade implements ApplicationRunner {
    private static final String COURSE = "java-mastery";
    private static final String BUILT_IN_LESSONS = """
            FROM lesson l
            JOIN course_module m ON m.id = l.module_id
            JOIN course c ON c.id = m.course_id
            """;

    private final JdbcTemplate jdbc;

    LessonProseUpgrade(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        var lessons = jdbc.query(
                "SELECT l.id, l.content AS body " + BUILT_IN_LESSONS
                        + "WHERE c.slug = ? AND l.content IS NOT NULL",
                (rs, row) -> new TextRow(rs.getLong("id"), rs.getString("body")), COURSE);
        for (var lesson : lessons) {
            String cleaned = LessonProse.clean(lesson.body());
            if (!cleaned.equals(lesson.body())) {
                jdbc.update("UPDATE lesson SET content = ? WHERE id = ? AND content = ?",
                        cleaned, lesson.id(), lesson.body());
            }
        }

        var indexRows = jdbc.query(
                "SELECT s.id, s.body_text AS body " + BUILT_IN_LESSONS
                        + "JOIN search_index s ON s.target_id = l.id AND s.target_type = 'LESSON' "
                        + "WHERE c.slug = ? AND s.body_text IS NOT NULL",
                (rs, row) -> new TextRow(rs.getLong("id"), rs.getString("body")), COURSE);
        for (var entry : indexRows) {
            String cleaned = LessonProse.clean(entry.body());
            if (!cleaned.equals(entry.body())) {
                jdbc.update("UPDATE search_index SET body_text = ? WHERE id = ? AND body_text = ?",
                        cleaned, entry.id(), entry.body());
            }
        }
    }

    private record TextRow(long id, String body) {}
}
