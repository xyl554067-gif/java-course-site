package com.javacourse.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.PreparedStatement;
import java.util.*;

/** Private question authoring plus a shared, read-only starter question bank. */
@Service
public class QuestionBankService {
    private static final Set<String> TYPES = Set.of("CHOICE", "JUDGE", "SHORT_ANSWER");
    private static final Set<String> DIFFICULTIES = Set.of("EASY", "MEDIUM", "HARD");

    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;

    public QuestionBankService(JdbcTemplate jdbc, ObjectMapper mapper) {
        this.jdbc = jdbc;
        this.mapper = mapper;
    }

    public List<Map<String, Object>> list(long ownerId) {
        return jdbc.query("SELECT q.id,q.lesson_id,q.owner_id,q.question,q.answer_text,q.options_json,q.answer_key,q.qa_type,q.difficulty,l.title AS lesson_title,l.slug AS lesson_slug "
                        + "FROM qa_item q LEFT JOIN lesson l ON l.id=q.lesson_id WHERE q.owner_id IS NULL OR q.owner_id=? "
                        + "ORDER BY CASE WHEN q.owner_id IS NULL THEN 0 ELSE 1 END,q.id DESC",
                (rs, row) -> mapRow(rs), ownerId);
    }

    public List<Map<String, Object>> lessons() {
        return jdbc.query("SELECT l.id,l.title,l.slug,m.title AS module_title,c.title AS course_title "
                        + "FROM lesson l JOIN course_module m ON m.id=l.module_id JOIN course c ON c.id=m.course_id "
                        + "ORDER BY c.sort_order,m.sort_order,l.sort_order",
                (rs, row) -> {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("id", rs.getLong("id"));
                    item.put("title", rs.getString("title"));
                    item.put("slug", rs.getString("slug"));
                    item.put("moduleTitle", rs.getString("module_title"));
                    item.put("courseTitle", rs.getString("course_title"));
                    return item;
                });
    }

    @Transactional
    public Map<String, Object> create(long ownerId, Map<String, Object> raw) {
        Item item = validate(raw);
        ensureNotDuplicate(ownerId, item, null);
        long id = insert(ownerId, item);
        return getMine(ownerId, id);
    }

    @Transactional
    public Map<String, Object> update(long ownerId, long id, Map<String, Object> raw) {
        Item item = validate(raw);
        ensureOwned(ownerId, id);
        ensureNotDuplicate(ownerId, item, id);
        int changed = jdbc.update("UPDATE qa_item SET lesson_id=?,question=?,answer_text=?,options_json=?,answer_key=?,qa_type=?,difficulty=? WHERE id=? AND owner_id=?",
                item.lessonId(), item.question(), item.answer(), item.options(), item.answerKey(), item.type(), item.difficulty(), id, ownerId);
        if (changed == 0) throw new IllegalArgumentException("找不到这道个人题目");
        return getMine(ownerId, id);
    }

    @Transactional
    public void delete(long ownerId, long id) {
        int deleted = jdbc.update("DELETE FROM qa_item WHERE id=? AND owner_id=?", id, ownerId);
        if (deleted == 0) throw new IllegalArgumentException("找不到这道个人题目");
    }

    @Transactional
    public Map<String, Object> importItems(long ownerId, List<?> rawItems) {
        if (rawItems == null || rawItems.isEmpty()) throw new IllegalArgumentException("导入文件里没有题目");
        if (rawItems.size() > 500) throw new IllegalArgumentException("一次最多导入 500 道题");
        int imported = 0, skipped = 0;
        for (int i = 0; i < rawItems.size(); i++) {
            if (!(rawItems.get(i) instanceof Map<?, ?> values)) {
                throw new IllegalArgumentException("第 " + (i + 1) + " 行不是有效题目对象");
            }
            Map<String, Object> raw = new HashMap<>();
            values.forEach((key, value) -> raw.put(String.valueOf(key), value));
            Item item;
            try {
                item = validate(raw);
            } catch (IllegalArgumentException e) {
                throw new IllegalArgumentException("第 " + (i + 1) + " 道题：" + e.getMessage());
            }
            if (isDuplicate(ownerId, item, null)) {
                skipped++;
                continue;
            }
            insert(ownerId, item);
            imported++;
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("imported", imported);
        result.put("skipped", skipped);
        result.put("total", rawItems.size());
        return result;
    }

    private Item validate(Map<String, Object> raw) {
        String question = value(raw, "question").trim();
        if (question.isEmpty()) throw new IllegalArgumentException("题目内容不能为空");
        if (question.length() > 512) throw new IllegalArgumentException("题目内容不能超过 512 个字符");

        String type = value(raw, "qaType", "type").trim().toUpperCase(Locale.ROOT);
        if ("SINGLE_CHOICE".equals(type) || "MULTIPLE_CHOICE".equals(type)) type = "CHOICE";
        if ("SHORT".equals(type) || "TEXT".equals(type)) type = "SHORT_ANSWER";
        if ("CODE".equals(type)) throw new IllegalArgumentException("代码题请添加到代码挑战，不要导入题库");
        if (!TYPES.contains(type)) throw new IllegalArgumentException("题型仅支持 CHOICE、JUDGE、SHORT_ANSWER");

        String difficulty = value(raw, "difficulty").trim().toUpperCase(Locale.ROOT);
        if (difficulty.isEmpty()) difficulty = "MEDIUM";
        if (!DIFFICULTIES.contains(difficulty)) throw new IllegalArgumentException("难度仅支持 EASY、MEDIUM、HARD");

        String answer = value(raw, "answer", "answerText").trim();
        String answerKey = value(raw, "answerKey", "answer_key").trim();
        if ("JUDGE".equals(type)) {
            answerKey = switch (answerKey.toUpperCase(Locale.ROOT)) {
                case "TRUE", "T", "YES", "CORRECT", "对", "正确" -> "TRUE";
                case "FALSE", "F", "NO", "WRONG", "错", "错误" -> "FALSE";
                default -> throw new IllegalArgumentException("判断题答案请填 TRUE/FALSE 或 对/错");
            };
        }
        String options = normalizeOptions(raw.get("options"));
        if ("CHOICE".equals(type)) {
            if (options == null) throw new IllegalArgumentException("选择题至少需要两个选项");
            try {
                JsonNode array = mapper.readTree(options);
                if (array == null || !array.isArray() || array.size() < 2) throw new IllegalArgumentException("选择题至少需要两个选项");
                for (JsonNode option : array) {
                    if (option == null || option.asText().isBlank()) throw new IllegalArgumentException("选择题选项不能为空");
                }
                int correctIndex = letterIndex(answerKey);
                if (correctIndex < 0 || correctIndex >= array.size()) throw new IllegalArgumentException("选择题答案请使用 A、B、C 等选项标号");
            } catch (IllegalArgumentException e) {
                throw e;
            } catch (Exception e) {
                throw new IllegalArgumentException("选择题选项必须是 JSON 数组，例如 [\"A. 选项\",\"B. 选项\"]");
            }
        }
        if (answer.isEmpty() && answerKey.isEmpty()) throw new IllegalArgumentException("请填写答案或解析");

        Long lessonId = resolveLesson(raw);
        return new Item(lessonId, question, answer, options, blankToNull(answerKey), type, difficulty);
    }

    private String normalizeOptions(Object raw) {
        if (raw == null) return null;
        if (raw instanceof List<?> list) {
            try { return mapper.writeValueAsString(list); }
            catch (Exception e) { throw new IllegalArgumentException("选项无法解析"); }
        }
        String value = String.valueOf(raw).trim();
        if (value.isEmpty()) return null;
        try {
            JsonNode parsed = mapper.readTree(value);
            if (parsed != null && parsed.isArray()) return mapper.writeValueAsString(parsed);
        } catch (Exception ignored) { }
        throw new IllegalArgumentException("选项请使用 JSON 数组格式，例如 [\"A. 选项\",\"B. 选项\"]");
    }

    private Long resolveLesson(Map<String, Object> raw) {
        Object idValue = raw.get("lessonId");
        if (idValue != null && !String.valueOf(idValue).isBlank()) {
            try {
                long id = Long.parseLong(String.valueOf(idValue));
                if (id <= 0 || jdbc.queryForObject("SELECT COUNT(*) FROM lesson WHERE id=?", Integer.class, id) == 0)
                    throw new IllegalArgumentException("所选课时不存在");
                return id;
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("课时编号无效");
            }
        }
        String slug = value(raw, "lessonSlug", "lesson_slug").trim();
        if (slug.isEmpty()) return null;
        List<Long> ids = jdbc.query("SELECT id FROM lesson WHERE slug=?", (rs, row) -> rs.getLong(1), slug);
        if (ids.isEmpty()) throw new IllegalArgumentException("找不到课时：" + slug);
        return ids.get(0);
    }

    private void ensureOwned(long ownerId, long id) {
        Integer count = jdbc.queryForObject("SELECT COUNT(*) FROM qa_item WHERE id=? AND owner_id=?", Integer.class, id, ownerId);
        if (count == null || count == 0) throw new IllegalArgumentException("找不到这道个人题目");
    }

    private void ensureNotDuplicate(long ownerId, Item item, Long exceptId) {
        if (isDuplicate(ownerId, item, exceptId)) throw new IllegalArgumentException("你已添加过这道课时题目");
    }

    private boolean isDuplicate(long ownerId, Item item, Long exceptId) {
        String sql = "SELECT COUNT(*) FROM qa_item WHERE owner_id=? AND question=? AND ((lesson_id=?) OR (lesson_id IS NULL AND ? IS NULL))";
        List<Object> args = new ArrayList<>(Arrays.asList(ownerId, item.question(), item.lessonId(), item.lessonId()));
        if (exceptId != null) { sql += " AND id<>?"; args.add(exceptId); }
        Integer count = jdbc.queryForObject(sql, Integer.class, args.toArray());
        return count != null && count > 0;
    }

    private long insert(long ownerId, Item item) {
        KeyHolder keys = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("INSERT INTO qa_item(lesson_id,owner_id,question,answer_text,options_json,answer_key,qa_type,difficulty) VALUES(?,?,?,?,?,?,?,?)", new String[]{"id"});
            if (item.lessonId() == null) ps.setNull(1, java.sql.Types.BIGINT); else ps.setLong(1, item.lessonId());
            ps.setLong(2, ownerId);
            ps.setString(3, item.question());
            ps.setString(4, item.answer());
            ps.setString(5, item.options());
            ps.setString(6, item.answerKey());
            ps.setString(7, item.type());
            ps.setString(8, item.difficulty());
            return ps;
        }, keys);
        Number key = keys.getKey();
        if (key != null) return key.longValue();
        return jdbc.queryForObject("SELECT id FROM qa_item WHERE owner_id=? AND question=? ORDER BY id DESC", Long.class, ownerId, item.question());
    }

    private Map<String, Object> getMine(long ownerId, long id) {
        List<Map<String, Object>> rows = jdbc.query("SELECT q.id,q.lesson_id,q.owner_id,q.question,q.answer_text,q.options_json,q.answer_key,q.qa_type,q.difficulty,l.title AS lesson_title,l.slug AS lesson_slug "
                        + "FROM qa_item q LEFT JOIN lesson l ON l.id=q.lesson_id WHERE q.id=? AND q.owner_id=?",
                (rs, row) -> mapRow(rs), id, ownerId);
        if (rows.isEmpty()) throw new IllegalArgumentException("找不到这道个人题目");
        return rows.get(0);
    }

    private Map<String, Object> mapRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        Map<String, Object> item = new LinkedHashMap<>();
        long owner = rs.getLong("owner_id");
        item.put("id", rs.getLong("id"));
        Object lessonId = rs.getObject("lesson_id");
        item.put("lessonId", lessonId == null ? null : ((Number) lessonId).longValue());
        item.put("lessonTitle", rs.getString("lesson_title"));
        item.put("lessonSlug", rs.getString("lesson_slug"));
        item.put("question", rs.getString("question"));
        item.put("answer", rs.getString("answer_text"));
        item.put("options", rs.getString("options_json"));
        item.put("answerKey", rs.getString("answer_key"));
        item.put("qaType", rs.getString("qa_type"));
        item.put("difficulty", rs.getString("difficulty"));
        item.put("mine", !rs.wasNull() && owner > 0);
        return item;
    }

    private String value(Map<String, Object> values, String... keys) {
        for (String key : keys) {
            Object value = values.get(key);
            if (value != null) return String.valueOf(value);
        }
        return "";
    }

    private int letterIndex(String key) {
        if (key == null || key.length() != 1) return -1;
        char c = Character.toUpperCase(key.charAt(0));
        return c >= 'A' && c <= 'Z' ? c - 'A' : -1;
    }

    private String blankToNull(String value) { return value == null || value.isBlank() ? null : value; }

    private record Item(Long lessonId, String question, String answer, String options,
                        String answerKey, String type, String difficulty) { }
}
