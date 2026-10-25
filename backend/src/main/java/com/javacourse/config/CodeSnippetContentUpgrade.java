package com.javacourse.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.Map;

/** Replaces fragmentary built-in code cards with complete, visible Java programs once. */
@Component
@Order(Ordered.LOWEST_PRECEDENCE)
public class CodeSnippetContentUpgrade implements ApplicationRunner {
    private static final String VERSION = "2026-10-26-complete-java-demo-snippets";

    private static final Map<String, String> COMPLETE_SNIPPETS = Map.ofEntries(
            Map.entry("基本类型占用的字节", """
                    public class BasicTypesDemo {
                        public static void main(String[] args) {
                            byte byteValue = 127;
                            short shortValue = 32000;
                            int intValue = 2_100_000_000;
                            long longValue = 9_000_000_000L;
                            float floatValue = 0.1f;
                            double doubleValue = 0.1 + 0.2;
                            char charValue = 'J';
                            boolean booleanValue = true;

                            System.out.println("byte: " + Byte.BYTES + " 字节, 示例值=" + byteValue);
                            System.out.println("short: " + Short.BYTES + " 字节, 示例值=" + shortValue);
                            System.out.println("int: " + Integer.BYTES + " 字节, 示例值=" + intValue);
                            System.out.println("long: " + Long.BYTES + " 字节, 示例值=" + longValue);
                            System.out.println("float: " + Float.BYTES + " 字节, 示例值=" + floatValue);
                            System.out.println("double: " + Double.BYTES + " 字节, 示例值=" + doubleValue);
                            System.out.println("char: " + Character.BYTES + " 字节, 示例值=" + charValue);
                            System.out.println("boolean: 大小由 JVM 实现决定, 示例值=" + booleanValue);
                        }
                    }
                    """),
            Map.entry("自增运算的差异", """
                    import java.math.BigDecimal;

                    public class OperatorDemo {
                        public static void main(String[] args) {
                            int i = 1;
                            int post = i++;
                            int j = 1;
                            int pre = ++j;
                            System.out.println("i++: 返回 " + post + ", 之后 i=" + i);
                            System.out.println("++j: 返回 " + pre + ", 之后 j=" + j);

                            System.out.println("0.1 + 0.2 = " + (0.1 + 0.2));
                            System.out.println("0.1 + 0.2 == 0.3: " + (0.1 + 0.2 == 0.3));
                            System.out.println("BigDecimal 精确结果: "
                                    + new BigDecimal("0.1").add(new BigDecimal("0.2")));
                        }
                    }
                    """),
            Map.entry("数组越界异常", """
                    public class ArrayBoundsDemo {
                        public static void main(String[] args) {
                            int[] nums = new int[5];
                            System.out.println(nums[0]); // 正常：下标从 0 开始

                            try {
                                System.out.println(nums[5]); // 故意越界，观察并捕获异常
                            } catch (ArrayIndexOutOfBoundsException e) {
                                System.out.println("已捕获越界异常：" + e.getClass().getSimpleName());
                            }

                            System.out.println("安全遍历：");
                            for (int n : nums) {
                                System.out.println(n);
                            }
                        }
                    }
                    """),
            Map.entry("值传递的本质", """
                    public class PassByValueDemo {
                        static class Box {
                            int value;
                        }

                        static void modify(Box box) {
                            box.value = 100; // 修改共享对象的字段
                        }

                        static void reassign(Box box) {
                            box = new Box(); // 只修改形参保存的引用副本
                            box.value = 200;
                        }

                        public static void main(String[] args) {
                            Box box = new Box();
                            box.value = 1;
                            modify(box);
                            System.out.println("modify 后: " + box.value);
                            reassign(box);
                            System.out.println("reassign 后调用方仍看到: " + box.value);
                        }
                    }
                    """),
            Map.entry("多态的运行时绑定", """
                    public class PolymorphismDemo {
                        abstract static class Animal {
                            abstract void sound();
                        }

                        static class Dog extends Animal {
                            @Override
                            void sound() {
                                System.out.println("汪汪");
                            }
                        }

                        public static void main(String[] args) {
                            Animal animal = new Dog();
                            animal.sound(); // 按对象的实际类型调用 Dog.sound()
                        }
                    }
                    """),
            Map.entry("泛型擦除的证据", """
                    import java.util.ArrayList;
                    import java.util.List;

                    public class TypeErasureDemo {
                        public static void main(String[] args) {
                            List<String> strings = new ArrayList<>();
                            List<Integer> integers = new ArrayList<>();
                            System.out.println(strings.getClass() == integers.getClass());
                            System.out.println("运行时类型: " + strings.getClass().getName());
                            // List<int> values = new ArrayList<>(); // 编译错误：泛型不能使用基本类型
                        }
                    }
                    """),
            Map.entry("反射读取注解", """
                    import java.lang.annotation.Retention;
                    import java.lang.annotation.RetentionPolicy;
                    import java.lang.reflect.Method;

                    public class AnnotationReflectionDemo {
                        @Retention(RetentionPolicy.RUNTIME)
                        @interface MyAnno {
                            String value();
                        }

                        static class Target {
                            @MyAnno("hello")
                            public void run() {
                            }
                        }

                        public static void main(String[] args) throws Exception {
                            Method method = Target.class.getMethod("run");
                            MyAnno annotation = method.getAnnotation(MyAnno.class);
                            System.out.println(annotation.value());
                        }
                    }
                    """),
            Map.entry("HashMap 扩容逻辑", """
                    import java.util.HashMap;
                    import java.util.Map;

                    public class HashMapResizeDemo {
                        public static void main(String[] args) {
                            String key = "java";
                            int hash = key.hashCode();
                            hash ^= (hash >>> 16); // 让高位也参与哈希扰动
                            int capacity = 16;
                            int index = hash & (capacity - 1);

                            Map<String, Integer> scores = new HashMap<>(capacity);
                            scores.put(key, 100);
                            System.out.println("扰动后哈希: " + hash);
                            System.out.println("示例桶下标: " + index);
                            System.out.println("默认负载因子 0.75 的阈值约为: " + (int) (capacity * 0.75));
                            System.out.println("Map 内容: " + scores);
                        }
                    }
                    """),
            Map.entry("Stream 分组统计", """
                    import java.util.List;
                    import java.util.Map;
                    import java.util.stream.Collectors;

                    public class StreamGroupingDemo {
                        record User(String name, String grade, int score) {
                        }

                        public static void main(String[] args) {
                            List<User> users = List.of(
                                    new User("小林", "A", 92),
                                    new User("小周", "A", 85),
                                    new User("小陈", "B", 76),
                                    new User("小吴", "B", 58));

                            Map<String, Long> stats = users.stream()
                                    .filter(user -> user.score() >= 60)
                                    .collect(Collectors.groupingBy(
                                            User::grade,
                                            Collectors.counting()));
                            System.out.println(stats);
                        }
                    }
                    """),
            Map.entry("可达性分析", """
                    public class GcRootsDemo {
                        private static Object staticRoot;

                        public static void main(String[] args) {
                            Object localRoot = new Object();
                            staticRoot = new Object();
                            System.out.println("局部变量和静态字段都可以持有 GC Roots 可达对象");
                            System.out.println("局部对象仍可访问: " + (localRoot != null));
                            System.out.println("静态对象仍可访问: " + (staticRoot != null));
                        }
                    }
                    """),
            Map.entry("线程池核心参数", """
                    import java.util.concurrent.LinkedBlockingQueue;
                    import java.util.concurrent.ThreadPoolExecutor;
                    import java.util.concurrent.TimeUnit;

                    public class ThreadPoolDemo {
                        public static void main(String[] args) throws InterruptedException {
                            ThreadPoolExecutor pool = new ThreadPoolExecutor(
                                    2,
                                    4,
                                    60, TimeUnit.SECONDS,
                                    new LinkedBlockingQueue<>(16),
                                    new ThreadPoolExecutor.CallerRunsPolicy());

                            for (int i = 1; i <= 3; i++) {
                                int taskId = i;
                                pool.execute(() -> System.out.println("执行任务 " + taskId));
                            }
                            pool.shutdown();
                            pool.awaitTermination(2, TimeUnit.SECONDS);
                        }
                    }
                    """),
            Map.entry("CompletableFuture 并行聚合", """
                    import java.util.concurrent.CompletableFuture;
                    import java.util.concurrent.TimeUnit;

                    public class CompletableFutureDemo {
                        public static void main(String[] args) throws Exception {
                            CompletableFuture<String> first = CompletableFuture.supplyAsync(() -> "Java");
                            CompletableFuture<String> second = CompletableFuture.supplyAsync(() -> "课程");

                            String result = first.thenCombine(second, (a, b) -> a + " " + b)
                                    .thenApply(String::toUpperCase)
                                    .get(5, TimeUnit.SECONDS);
                            System.out.println(result);
                        }
                    }
                    """),
            Map.entry("KingBase JDBC 连接", """
                    import java.sql.Connection;
                    import java.sql.DriverManager;
                    import java.sql.PreparedStatement;
                    import java.sql.ResultSet;
                    import java.sql.SQLException;

                    public class KingbaseJdbcDemo {
                        public static void main(String[] args) {
                            String url = System.getenv().getOrDefault("KB_URL",
                                    "jdbc:kingbase8://127.0.0.1:54321/javacourse?currentSchema=public&characterEncoding=UTF-8");
                            String user = System.getenv().getOrDefault("KB_USER", "javacourse_app");
                            String password = System.getenv().getOrDefault("KB_PASSWORD", "change-me");

                            String sql = "SELECT id, title FROM lesson WHERE module_id = ?";
                            try (Connection connection = DriverManager.getConnection(url, user, password);
                                 PreparedStatement statement = connection.prepareStatement(sql)) {
                                statement.setLong(1, 1L);
                                try (ResultSet rows = statement.executeQuery()) {
                                    while (rows.next()) {
                                        System.out.println(rows.getLong("id") + ": " + rows.getString("title"));
                                    }
                                }
                            } catch (SQLException e) {
                                System.err.println("连接失败：请配置 KingBase JDBC 驱动和 KB_URL/KB_USER/KB_PASSWORD。 ");
                                System.err.println(e.getMessage());
                            }
                        }
                    }
                    """));

    private final JdbcTemplate jdbc;

    public CodeSnippetContentUpgrade(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void run(ApplicationArguments args) {
        jdbc.execute("CREATE TABLE IF NOT EXISTS app_schema_migration ("
                + "version VARCHAR(120) PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP)");
        Integer applied = jdbc.queryForObject(
                "SELECT COUNT(*) FROM app_schema_migration WHERE version = ?", Integer.class, VERSION);
        if (applied != null && applied > 0) {
            return;
        }

        COMPLETE_SNIPPETS.forEach((title, source) -> jdbc.update(
                "UPDATE code_snippet SET code_text = ? WHERE language = 'java' AND title = ?",
                source, title));
        jdbc.update("INSERT INTO app_schema_migration(version) VALUES (?) ON CONFLICT (version) DO NOTHING", VERSION);
    }
}

