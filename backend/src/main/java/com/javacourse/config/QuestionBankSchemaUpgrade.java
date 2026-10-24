package com.javacourse.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.DatabaseMetaData;
import java.util.List;

/** Adds ownership to existing question tables and inserts the small public starter bank once. */
@Component
public class QuestionBankSchemaUpgrade implements ApplicationRunner {
    private final JdbcTemplate jdbc;

    public QuestionBankSchemaUpgrade(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        try (var connection = jdbc.getDataSource().getConnection()) {
            DatabaseMetaData metadata = connection.getMetaData();
            if (!hasColumn(metadata, "qa_item", "owner_id")) {
                jdbc.execute("ALTER TABLE qa_item ADD COLUMN owner_id BIGINT");
            }
            if (!hasForeignKey(metadata, "qa_item", "fk_qa_owner")) {
                jdbc.execute("ALTER TABLE qa_item ADD CONSTRAINT fk_qa_owner FOREIGN KEY (owner_id) REFERENCES app_user(id) ON DELETE CASCADE");
            }
        }
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_qa_owner ON qa_item(owner_id, id)");
        seedStarterQuestions();
    }

    private boolean hasColumn(DatabaseMetaData metadata, String table, String column) throws Exception {
        for (String candidate : List.of(table, table.toUpperCase())) {
            try (var columns = metadata.getColumns(null, null, candidate, null)) {
                while (columns.next()) {
                    if (column.equalsIgnoreCase(columns.getString("COLUMN_NAME"))) return true;
                }
            }
        }
        return false;
    }

    private boolean hasForeignKey(DatabaseMetaData metadata, String table, String name) throws Exception {
        for (String candidate : List.of(table, table.toUpperCase())) {
            try (var keys = metadata.getImportedKeys(null, null, candidate)) {
                while (keys.next()) {
                    if (name.equalsIgnoreCase(keys.getString("FK_NAME"))) return true;
                }
            }
        }
        return false;
    }

    private void seedStarterQuestions() {
        List<SeedQuestion> questions = List.of(
                new SeedQuestion("hello-world", "Java 程序通常从哪个方法开始执行？", "Java 虚拟机从符合签名的 main 方法开始执行应用程序。", "[\"A. start()\",\"B. main()\",\"C. run()\",\"D. init()\"]", "B", "CHOICE", "EASY"),
                new SeedQuestion("variables-and-types", "Java 的基本数据类型一共有多少种？", "Java 有 8 种基本数据类型：4 种整数/字符类型、2 种浮点类型和 2 种布尔类型。", "[\"A. 6 种\",\"B. 7 种\",\"C. 8 种\",\"D. 9 种\"]", "C", "CHOICE", "EASY"),
                new SeedQuestion("variables-and-types", "Java 的 char 类型可以存储一个 Unicode 字符。", "char 使用 16 位无符号值表示 UTF-16 代码单元。", "[\"正确\",\"错误\"]", "TRUE", "JUDGE", "EASY"),
                new SeedQuestion("operators", "表达式 int x = 3; int y = x++; 执行后 y 的值是多少？", "后置自增先返回原值，再将 x 加一，因此 y 为 3。", "[\"A. 2\",\"B. 3\",\"C. 4\",\"D. 编译错误\"]", "B", "CHOICE", "EASY"),
                new SeedQuestion("control-flow", "在 switch 语句中，break 通常用于什么？", "break 结束当前 switch 分支，避免继续执行后续分支。", "[\"A. 跳过本轮循环\",\"B. 结束 switch\",\"C. 重启程序\",\"D. 声明变量\"]", "B", "CHOICE", "EASY"),
                new SeedQuestion("arrays", "Java 数组的第一个元素下标是 0。", "Java 数组采用从 0 开始的下标。", "[\"正确\",\"错误\"]", "TRUE", "JUDGE", "EASY"),
                new SeedQuestion("string", "为什么循环拼接大量字符串时通常使用 StringBuilder？", "String 不可变，反复拼接会产生多个中间对象；StringBuilder 可在可变缓冲区中追加内容。", null, null, "SHORT_ANSWER", "MEDIUM"),
                new SeedQuestion("class-and-object", "面向对象中的封装主要解决什么问题？", "封装将状态和操作组织在一起，并通过访问控制保护对象内部状态、隐藏实现细节。", null, null, "SHORT_ANSWER", "MEDIUM"),
                new SeedQuestion("collection-overview", "HashMap 中键的唯一性主要由哪两个方法共同决定？", "键的定位与比较依赖 hashCode() 和 equals()。", null, null, "SHORT_ANSWER", "MEDIUM"),
                new SeedQuestion("jvm-memory", "Java 对象实例通常分配在哪个内存区域？", "通常分配在 Java 堆中；逃逸分析等优化可能改变实际分配方式。", "[\"A. 程序计数器\",\"B. Java 堆\",\"C. 虚拟机栈\",\"D. 方法参数表\"]", "B", "CHOICE", "MEDIUM"),
                new SeedQuestion("thread-pool", "线程池中任务队列已满、最大线程数也已达到时，会发生什么？", "线程池按配置的拒绝策略处理新提交的任务。", null, null, "SHORT_ANSWER", "MEDIUM")
        );
        for (SeedQuestion q : questions) {
            jdbc.update("INSERT INTO qa_item(lesson_id,owner_id,question,answer_text,options_json,answer_key,qa_type,difficulty) "
                            + "SELECT (SELECT id FROM lesson WHERE slug=?),NULL,?,?,?,?,?,? "
                            + "WHERE EXISTS(SELECT 1 FROM lesson WHERE slug=?) "
                            + "AND NOT EXISTS(SELECT 1 FROM qa_item WHERE owner_id IS NULL AND question=?)",
                    q.lessonSlug(), q.question(), q.answer(), q.options(), q.answerKey(), q.type(), q.difficulty(), q.lessonSlug(), q.question());
        }
    }

    private record SeedQuestion(String lessonSlug, String question, String answer, String options,
                                String answerKey, String type, String difficulty) { }
}
