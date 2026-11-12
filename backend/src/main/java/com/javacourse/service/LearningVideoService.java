package com.javacourse.service;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.util.regex.Pattern;

@Service
public class LearningVideoService {
    private static final Pattern VIDEO_PATH = Pattern.compile("/video/(BV[0-9A-Za-z]{10})/?");
    private final JdbcTemplate jdbc;

    public LearningVideoService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record VideoInput(String url, String title, String uploader, long lessonId, String label,
                             int partNumber, int startSeconds, String recommendation, int sortOrder) {}

    @Transactional
    public void save(Long id, VideoInput input) {
        String bvid = videoId(input.url());
        String title = required(input.title(), 160, "视频标题");
        String uploader = required(input.uploader(), 100, "UP 主");
        String label = required(input.label(), 160, "课时内标题");
        String recommendation = input.recommendation() == null ? null : input.recommendation().strip();
        if (recommendation != null && recommendation.length() > 512) {
            throw new IllegalArgumentException("推荐理由最多 512 字");
        }
        if (input.partNumber() < 1 || input.startSeconds() < 0 || input.sortOrder() < 0) {
            throw new IllegalArgumentException("分集至少为 1，起始秒数和排序不能小于 0");
        }
        Integer lessonCount = jdbc.queryForObject("""
                SELECT COUNT(*) FROM lesson l
                JOIN course_module m ON m.id = l.module_id
                JOIN course c ON c.id = m.course_id
                WHERE l.id = ? AND c.status = 'PUBLISHED'
                """, Integer.class, input.lessonId());
        if (lessonCount == null || lessonCount == 0) {
            throw new IllegalArgumentException("请选择已发布课程中的课时");
        }

        jdbc.update("""
                INSERT INTO learning_video (bvid, source_url, title, uploader) VALUES (?, ?, ?, ?)
                ON CONFLICT (bvid) DO UPDATE SET title = EXCLUDED.title, uploader = EXCLUDED.uploader
                """, bvid, "https://www.bilibili.com/video/" + bvid + "/", title, uploader);
        Long videoId = jdbc.queryForObject("SELECT id FROM learning_video WHERE bvid = ?", Long.class, bvid);
        try {
            if (id == null) {
                jdbc.update("""
                        INSERT INTO lesson_video
                            (lesson_id, video_id, part_number, start_seconds, label, recommendation, sort_order)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """, input.lessonId(), videoId, input.partNumber(), input.startSeconds(),
                        label, recommendation, input.sortOrder());
            } else if (jdbc.update("""
                    UPDATE lesson_video SET lesson_id = ?, video_id = ?, part_number = ?, start_seconds = ?,
                                            label = ?, recommendation = ?, sort_order = ? WHERE id = ?
                    """, input.lessonId(), videoId, input.partNumber(), input.startSeconds(),
                    label, recommendation, input.sortOrder(), id) == 0) {
                throw new IllegalArgumentException("这条课时关联已移除，请刷新列表");
            }
        } catch (DuplicateKeyException e) {
            throw new IllegalArgumentException("这个课时已经关联了同一分集和起始时间");
        }
    }

    public void remove(long id) {
        jdbc.update("DELETE FROM lesson_video WHERE id = ?", id);
    }

    private static String videoId(String url) {
        try {
            URI uri = URI.create(url == null ? "" : url.strip());
            String host = uri.getHost();
            if ("https".equalsIgnoreCase(uri.getScheme()) && uri.getUserInfo() == null && uri.getPort() == -1
                    && ("www.bilibili.com".equalsIgnoreCase(host) || "bilibili.com".equalsIgnoreCase(host))) {
                var match = VIDEO_PATH.matcher(uri.getRawPath());
                if (match.matches()) return match.group(1);
            }
        } catch (IllegalArgumentException ignored) {
            // Return the same validation message for malformed and unsupported URLs.
        }
        throw new IllegalArgumentException("请输入 B 站视频的 HTTPS 原链接（含 BV 号）");
    }

    private static String required(String value, int limit, String field) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException("请填写" + field);
        String trimmed = value.strip();
        if (trimmed.length() > limit) throw new IllegalArgumentException(field + "最多 " + limit + " 字");
        return trimmed;
    }
}
