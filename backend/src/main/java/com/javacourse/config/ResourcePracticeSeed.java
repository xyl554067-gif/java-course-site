package com.javacourse.config;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.util.List;

/** Installs the shared knowledge questions and code exercises linked to study notes. */
@Component
public class ResourcePracticeSeed {
    private static final String INCOMPLETE_METHOD = "throw new UnsupportedOperationException(\"请完成方法\");";

    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;

    public ResourcePracticeSeed(JdbcTemplate jdbc, ObjectMapper mapper) {
        this.jdbc = jdbc;
        this.mapper = mapper;
    }

    @Transactional(rollbackFor = IOException.class)
    public void apply() throws IOException {
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS app_schema_migration (
                    version VARCHAR(120) PRIMARY KEY,
                    applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
                )
                """);
        if (claim("resource-practice-question-link-v1")) {
            jdbc.execute("ALTER TABLE qa_item ADD COLUMN IF NOT EXISTS resource_note_id VARCHAR(80)");
        }

        try (var input = new ClassPathResource("db/seed-resource-practice.json").getInputStream()) {
            List<Practice> practices = mapper.readValue(input, new TypeReference<>() {});
            for (Practice practice : practices) {
                seed(practice);
            }
        }
    }

    private boolean claim(String version) {
        return jdbc.update("""
                INSERT INTO app_schema_migration (version) VALUES (?)
                ON CONFLICT (version) DO NOTHING
                """, version) > 0;
    }

    private void seed(Practice practice) throws IOException {
        List<Long> lessonIds = jdbc.queryForList("""
                SELECT l.id FROM lesson l
                JOIN course_module m ON m.id = l.module_id
                JOIN course c ON c.id = m.course_id
                WHERE c.slug = 'java-mastery' AND l.slug = ?
                """, Long.class, practice.lessonSlug());
        if (lessonIds.isEmpty() || !claim("resource-practice-v1-" + practice.noteId())) {
            return;
        }
        long lessonId = lessonIds.get(0);
        Question question = practice.question();
        String options = question.options() == null ? null : mapper.writeValueAsString(question.options());
        jdbc.update("""
                INSERT INTO qa_item (lesson_id, resource_note_id, question, answer_text, options_json,
                                     answer_key, qa_type, difficulty)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, lessonId, practice.noteId(), question.prompt(), question.explanation(), options,
                question.answerKey(), question.type(), question.difficulty());

        Exercise exercise = practice.exercise();
        String starter = String.join("\n", exercise.starterCode());
        String unfinishedLine = exercise.starterCode().stream()
                .filter(line -> line.strip().equals(INCOMPLETE_METHOD))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Missing exercise placeholder for " + practice.noteId()));
        String solution = starter.replace(unfinishedLine, String.join("\n", exercise.solutionBody()));
        jdbc.update("""
                INSERT INTO code_exercise (lesson_id, slug, title, description, difficulty, language, starter_code,
                                           solution_code, test_cases, hint, sort_order)
                VALUES (?, ?, ?, ?, ?, 'java', ?, ?, ?, ?, ?)
                """, lessonId, "resource-" + practice.noteId(), exercise.title(), exercise.description(),
                exercise.difficulty(), starter, solution, mapper.writeValueAsString(exercise.cases()),
                exercise.hint(), exercise.sortOrder());
    }

    private record Practice(String noteId, String lessonSlug, Question question, Exercise exercise) {}

    private record Question(String prompt, String type, String difficulty, List<String> options,
                            String answerKey, String explanation) {}

    private record Exercise(String title, String description, String difficulty, String hint, int sortOrder,
                            List<String> starterCode, List<String> solutionBody, List<TestCase> cases) {}

    private record TestCase(String name, String stdin, String expected) {}
}
