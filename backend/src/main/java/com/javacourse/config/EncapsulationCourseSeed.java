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
import java.util.List;

import static java.nio.charset.StandardCharsets.UTF_8;

@Component
@Order(Ordered.LOWEST_PRECEDENCE - 1)
class EncapsulationCourseSeed implements ApplicationRunner {
    private static final String COURSE_SLUG = "java-encapsulation";
    private static final String COURSE_TITLE = "封装、访问控制与包管理";
    private static final String SHORT_LESSON_VERSION = "encapsulation-beginner-lesson-v2";
    private static final List<Lesson> LESSONS = List.of(
            new Lesson("account", "从余额开始理解封装", "用 private 和受控方法守住余额规则，验证失败的存款不会修改余额。",
                    "封装 数据封装 Account Java private getter deposit", 15),
            new Lesson("access", "判断四种访问权限", "对照权限表判断同包与跨包的访问，辨认 protected 对引用类型的要求。",
                    "访问控制 访问修饰符 public private protected package-private", 20),
            new Lesson("packages", "组织包并修复访问错误", "从两个源文件着手，复现跨包访问错误，再用公开接口修复并重新编译。",
                    "包管理 package import javac 跨包 子包 代码纠错", 25),
            new Lesson("refactor", "重构账户并通过边界测试", "把公开余额改成私有状态，用自动判题验证正常存款、非法金额和整数上限。",
                    "封装重构 实践 Account 自动判题 Integer.MAX_VALUE 边界测试", 25)
    );
    private final JdbcTemplate jdbc;

    EncapsulationCourseSeed(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    @Transactional(rollbackFor = IOException.class)
    public void run(ApplicationArguments args) throws IOException {
        int inserted = jdbc.update("""
                INSERT INTO course (slug, title, subtitle, description, version, sort_order, total_lessons)
                VALUES (?, ?, ?, ?, 'v1.0', 10, ?)
                ON CONFLICT (slug) DO NOTHING
                """, COURSE_SLUG, COURSE_TITLE, "用一个 Java 账户练习三道访问边界",
                "从保护余额到整理包结构。每节解决一个具体问题，最后用边界测试验收账户重构。", LESSONS.size());
        if (inserted > 0) {
            seedOriginalMaterials();
        }
        upgradeMainLesson();
    }

    private void seedOriginalMaterials() throws IOException {
        long courseId = jdbc.queryForObject("SELECT id FROM course WHERE slug = ?", Long.class, COURSE_SLUG);
        jdbc.update("""
                INSERT INTO course_module (course_id, title, summary, icon, lesson_count)
                VALUES (?, 'Java 账户实验', '把字段访问、继承访问与包边界用同一个案例连起来。', 'boxes', ?)
                """, courseId, LESSONS.size());
        long moduleId = jdbc.queryForObject("SELECT id FROM course_module WHERE course_id = ?", Long.class, courseId);
        index("COURSE", courseId, COURSE_TITLE, "Java 专题课程，含访问判断、代码纠错和封装重构练习。",
                "封装 访问控制 包管理", "/course/" + COURSE_SLUG);

        for (int i = 0; i < LESSONS.size(); i++) {
            Lesson lesson = LESSONS.get(i);
            String content = read(lesson.key() + ".md");
            jdbc.update("""
                    INSERT INTO lesson (module_id, slug, title, summary, content, duration_min, sort_order, is_preview)
                    VALUES (?, ?, ?, ?, ?, ?, ?, 1)
                    """, moduleId, lesson.slug(), lesson.title(), lesson.summary(), content, lesson.minutes(), i);
            index("LESSON", lessonId(lesson.key()), lesson.title(), content, lesson.keywords(), "/lesson/" + lesson.slug());
        }

        long accountId = lessonId("account");
        insertSnippet(accountId, "封装账户余额", "AccountDemo.java",
                "先预测三行输出。随后取消最后一行注释，观察对 private 字段的直接访问为何报错。",
                "true\nfalse\n100");
        jdbc.update("""
                INSERT INTO lesson_video (lesson_id, video_id, part_number, label, recommendation)
                SELECT ?, id, 82, '封装', '看完视频后，在右侧运行账户示例，试着存入一笔负数金额。'
                FROM learning_video WHERE bvid = 'BV1wL411L7A3'
                """, accountId);

        insertSnippet(lessonId("packages"), "同包访问对照实验", "PackageProbe.java",
                "该文件里的两个类位于同一个未命名包。把 branchCode() 调用改为直接访问 account.balance，再对比编译结果。",
                "BANK\n100");
        insertRefactorExercise(lessonId("refactor"));
    }

    private void upgradeMainLesson() throws IOException {
        int claimed = jdbc.update("""
                INSERT INTO app_schema_migration (version) VALUES (?)
                ON CONFLICT (version) DO NOTHING
                """, SHORT_LESSON_VERSION);
        if (claimed == 0) {
            return;
        }

        long mainLessonId = lessonId("account");
        String summary = "从班费账户认识类与对象，逐步理解封装、包和访问权限，再用一次跨包纠错验证所学。";
        String content = read("lesson.md");
        jdbc.update("""
                UPDATE lesson
                SET title = ?, summary = ?, content = ?, content_html = NULL, duration_min = 15
                WHERE id = ?
                """, COURSE_TITLE + "：账户案例", summary, content, mainLessonId);
        jdbc.update("""
                UPDATE course SET subtitle = '用班费账户入门 Java 封装', description = ?,
                                  version = 'v1.2', total_lessons = 1
                WHERE slug = ?
                """, summary, COURSE_SLUG);
        jdbc.update("""
                UPDATE course_module SET lesson_count = 1 WHERE id = (SELECT module_id FROM lesson WHERE id = ?)
                """, mainLessonId);
        jdbc.update("""
                UPDATE search_index SET title = ?, body_text = ?, tokens = ?
                WHERE target_type = 'LESSON' AND target_id = ?
                """, COURSE_TITLE + "：账户案例", content,
                "封装 访问控制 包管理 private protected public package import 重构 纠错", mainLessonId);
        jdbc.update("""
                UPDATE search_index SET body_text = ? WHERE target_type = 'COURSE'
                AND target_id = (SELECT id FROM course WHERE slug = ?)
                """, summary, COURSE_SLUG);
        linkKnowledge(mainLessonId, "数据封装与账户不变式", "封装", "私有字段保存余额，公开操作先验证金额与范围，再更新余额。");
        linkKnowledge(mainLessonId, "四种访问权限", "访问控制", "判断前检查成员修饰符、调用方所在包、继承关系，以及跨包 protected 调用的引用类型。");
        linkKnowledge(mainLessonId, "包声明、导入与类路径", "包管理", "package 确定类型归属，import 让简名可用，运行时用类路径和全限定类名定位入口。");
        linkKnowledge(mainLessonId, "边界测试验证封装重构", "实践", "对比合法、非法和溢出输入，检查返回值与失败前后的状态。");
    }

    private void linkKnowledge(long lessonId, String name, String category, String description) {
        jdbc.update("""
                INSERT INTO knowledge_point (name, category, description)
                VALUES (?, ?, ?) ON CONFLICT (name) DO NOTHING
                """, name, category, description);
        jdbc.update("""
                INSERT INTO lesson_knowledge (lesson_id, kp_id)
                SELECT ?, id FROM knowledge_point WHERE name = ?
                ON CONFLICT (lesson_id, kp_id) DO NOTHING
                """, lessonId, name);
    }

    private long lessonId(String key) {
        return jdbc.queryForObject("SELECT id FROM lesson WHERE slug = ?", Long.class, "encapsulation-" + key);
    }

    private void index(String type, long id, String title, String content, String keywords, String url) {
        jdbc.update("""
                INSERT INTO search_index (target_type, target_id, title, body_text, tokens, ref_url)
                VALUES (?, ?, ?, ?, ?, ?)
                """, type, id, title, content, keywords, url);
    }

    private void insertSnippet(long lessonId, String title, String file, String explanation,
                               String expectedOutput) throws IOException {
        jdbc.update("""
                INSERT INTO code_snippet (lesson_id, title, code_text, explanation, runnable, expected_out)
                VALUES (?, ?, ?, ?, TRUE, ?)
                """, lessonId, title, read(file), explanation, expectedOutput);
    }

    private void insertRefactorExercise(long lessonId) throws IOException {
        String tests = """
                [
                  {"name":"正常存款","stdin":"100 25","expected":"true\\n125"},
                  {"name":"拒绝零金额","stdin":"100 0","expected":"false\\n100"},
                  {"name":"拒绝负数","stdin":"100 -20","expected":"false\\n100"},
                  {"name":"拒绝整数溢出","stdin":"2147483647 1","expected":"false\\n2147483647"},
                  {"name":"允许恰好达到上限","stdin":"2147483646 1","expected":"true\\n2147483647"}
                ]
                """;
        jdbc.update("""
                INSERT INTO code_exercise (lesson_id, slug, title, description, starter_code, solution_code, test_cases, hint)
                VALUES (?, 'encapsulation-deposit', '保护账户余额',
                        '输入初始余额与存款金额。输出存款是否成功和操作后的余额，各占一行。把 balance 改为 private 并用 getter 读取。',
                        ?, ?, ?, '更新前先排除非正数金额，再比较金额与 Integer.MAX_VALUE - balance。')
                """, lessonId, read("BankRefactorStarter.java"), read("BankRefactorSolution.java"), tests);
    }

    private static String read(String file) throws IOException {
        return new ClassPathResource("db/courses/encapsulation/" + file).getContentAsString(UTF_8);
    }

    private record Lesson(String key, String title, String summary, String keywords, int minutes) {
        String slug() {
            return "encapsulation-" + key;
        }
    }
}
