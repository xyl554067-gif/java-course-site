package com.javacourse.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

import static java.nio.charset.StandardCharsets.UTF_8;

@Component
@Order(Ordered.LOWEST_PRECEDENCE)
class LessonProseUpgrade implements ApplicationRunner {
    private static final String COURSE = "java-mastery";
    private static final String BUILT_IN_LESSONS = """
            FROM lesson l
            JOIN course_module m ON m.id = l.module_id
            JOIN course c ON c.id = m.course_id
            """;

    private static final Pattern READING_LAYOUT = Pattern.compile(
            "(?m)^UPDATE lesson SET content = '((?:''|[^']++)*+)' WHERE slug = '([a-z0-9-]+)';");
    private final JdbcTemplate jdbc;

    LessonProseUpgrade(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) throws IOException {
        var layouts = readingLayouts();
        var legacyBodies = legacyReadingBodies();
        if (!layouts.keySet().equals(legacyBodies.keySet())) {
            throw new IOException("Reading layouts do not match the legacy lesson list");
        }
        var lessons = jdbc.query(
                "SELECT l.id, l.slug, l.content AS body " + BUILT_IN_LESSONS
                        + "WHERE c.slug = ? AND l.content IS NOT NULL",
                (rs, row) -> new LessonBody(rs.getLong("id"), rs.getString("slug"), rs.getString("body")), COURSE);
        for (var lesson : lessons) {
            String cleaned = LessonProse.clean(lesson.body());
            String revised = reviseLayout(lesson.slug(), cleaned, layouts, legacyBodies);
            if (!revised.equals(lesson.body())) {
                int updated = jdbc.update("UPDATE lesson SET content = ? WHERE id = ? AND content = ?",
                        revised, lesson.id(), lesson.body());
                if (updated > 0 && !revised.equals(cleaned)) {
                    jdbc.update("UPDATE search_index SET body_text = ? WHERE target_type = 'LESSON' AND target_id = ?",
                            revised, lesson.id());
                }
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

    private static Map<String, String> readingLayouts() throws IOException {
        String seed = new ClassPathResource("db/seed-content-enhanced.sql").getContentAsString(UTF_8);
        var match = READING_LAYOUT.matcher(seed.replace("\r\n", "\n"));
        Map<String, String> layouts = new HashMap<>();
        while (match.find()) layouts.put(match.group(2), match.group(1).replace("''", "'"));
        return layouts;
    }

    private static Map<String, Set<String>> legacyReadingBodies() throws IOException {
        String data = new ClassPathResource("db/lesson-reading-legacy.tsv").getContentAsString(UTF_8);
        Map<String, Set<String>> legacy = new HashMap<>();
        for (String line : data.lines().toList()) {
            String[] fields = line.split("\t");
            if (fields.length < 3) throw new IOException("Invalid legacy lesson fingerprint");
            legacy.put(fields[0], Set.copyOf(List.of(fields).subList(1, fields.length)));
        }
        return legacy;
    }

    /** Replace known seed versions and keep locally edited lesson bodies. */
    private static String reviseLayout(String slug, String body, Map<String, String> layouts,
                                       Map<String, Set<String>> legacyBodies) {
        Set<String> hashes = legacyBodies.get(slug);
        return hashes != null && hashes.contains(fingerprint(body)) ? layouts.get(slug) : body;
    }

    private static String fingerprint(String body) {
        String normalized = body.replace("\r\n", "\n").replace('\r', '\n').stripTrailing();
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(normalized.getBytes(UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is required by Java", e);
        }
    }

    private record LessonBody(long id, String slug, String body) {}
    private record TextRow(long id, String body) {}
}
