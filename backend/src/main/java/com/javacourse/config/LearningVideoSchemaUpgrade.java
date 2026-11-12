package com.javacourse.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class LearningVideoSchemaUpgrade implements ApplicationRunner {
    private static final String PILOT_BVID = "BV1gE411o7eC";
    private static final String CURATED_VIDEOS_VERSION = "2026-11-12-java-mastery-learning-videos";
    private final JdbcTemplate jdbc;

    public LearningVideoSchemaUpgrade(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        new ResourceDatabasePopulator(new ClassPathResource("db/upgrade-learning-videos.sql"))
                .execute(jdbc.getDataSource());

        // Seed links once so an administrator's edits or removals survive a restart.
        int inserted = jdbc.update("""
                INSERT INTO learning_video (bvid, source_url, title, uploader)
                SELECT ?, ?, ?, ?
                WHERE EXISTS (
                    SELECT 1 FROM lesson l JOIN course_module m ON m.id = l.module_id
                    JOIN course c ON c.id = m.course_id
                    WHERE l.slug = 'arrays' AND c.slug = 'java-mastery'
                )
                ON CONFLICT (bvid) DO NOTHING
                """, PILOT_BVID, "https://www.bilibili.com/video/" + PILOT_BVID + "/",
                "黑马程序员 JAVA 基础精讲", "黑马程序员");
        if (inserted > 0) {
            addPilotPart(85, "数组索引越界异常", "对照视频找出哪一次数组访问越界，再修改代码并重新运行。", 0);
            addPilotPart(79, "数组的遍历", "看完遍历示例后，试着用数组长度作为循环条件。", 1);
        }
        seedCuratedVideos();
    }

    private void seedCuratedVideos() {
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS app_schema_migration (
                    version VARCHAR(120) PRIMARY KEY,
                    applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
                )
                """);
        int claimed = jdbc.update("""
                INSERT INTO app_schema_migration (version)
                SELECT ? WHERE EXISTS (
                    SELECT 1 FROM lesson l JOIN course_module m ON m.id = l.module_id
                    JOIN course c ON c.id = m.course_id WHERE c.slug = 'java-mastery'
                )
                ON CONFLICT (version) DO NOTHING
                """, CURATED_VIDEOS_VERSION);
        if (claimed > 0) {
            var seed = new ResourceDatabasePopulator(
                    new ClassPathResource("db/seed-learning-videos-java-mastery.sql"));
            seed.setSqlScriptEncoding("UTF-8");
            seed.execute(jdbc.getDataSource());
        }
    }

    private void addPilotPart(int part, String label, String recommendation, int order) {
        jdbc.update("""
                INSERT INTO lesson_video (lesson_id, video_id, part_number, label, recommendation, sort_order)
                SELECT l.id, v.id, ?, ?, ?, ? FROM lesson l
                JOIN course_module m ON m.id = l.module_id
                JOIN course c ON c.id = m.course_id
                CROSS JOIN learning_video v
                WHERE l.slug = 'arrays' AND c.slug = 'java-mastery' AND v.bvid = ?
                """, part, label, recommendation, order, PILOT_BVID);
    }
}
