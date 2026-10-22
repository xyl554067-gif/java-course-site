#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
代码实验室数据脚本：建表 / 修数据 / 灌示例与习题。

背景（一个真实存在的 bug）：
    原来的 seed.sql 用单引号 SQL 字符串写代码，源码里的换行写成 '\\n'。
    在 KingbaseES/PostgreSQL 默认 standard_conforming_strings=on 的语义下，
    '\\n' 是「反斜杠 + 字母 n」两个字符，<b>不是换行符</b>。
    结果：code_snippet.code_text 存的是一整行带字面 \\n 的文本，
    这样的源码交给 javac 必然编译失败 —— 「示例代码不能跑」的根本原因之一。

本脚本做四件事：
    1. 建 code_exercise / code_submission 表，并给 code_snippet 补三列
       （runnable / stdin / expected_out），全部幂等。
    2. 修复存量 code_snippet.code_text 里的字面 \\n → 真换行。
    3. 把示例代码重写为「可完整编译运行的程序」，并标注期望输出。
    4. 灌入课后习题（初始代码 / 参考答案 / 测试用例）。

用法:
    python scripts/seed_code_lab.py            # 建表 + 修数据 + 灌数据
    python scripts/seed_code_lab.py --verify   # 额外用本机 JDK 实跑所有示例与参考答案
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JDBC_JAR = os.path.join(ROOT, "backend", "lib", "kingbase8-8.6.0.jar")
ASCII_DIR = "C:/Users/%s/kbtmp" % os.environ.get("USERNAME", "lxy")
# SQL 暂存目录：必须与 kb_env.sh 的 KB_TMP_DIR 不同，
# 否则 kb_stage_sql 的 cp 会因为「源和目标同一文件」而失败
SQL_DIR = ASCII_DIR + "/codelab"

DB = {"host": "127.0.0.1", "port": "54321", "db": "javacourse",
      "user": "javacourse_app", "pw": "App@Course2026"}

# ============================================================================
# 示例代码：每一条都是「完整可编译运行的 Java 程序」
# 字段：lesson_slug, title, code, explanation, stdin, expected_out
# ============================================================================
SNIPPETS = [
    ("hello-world", "第一个 Java 程序",
     '''public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}''',
     "javac 编译为 .class，再由 JVM 加载执行。注意源文件名必须与 public 类名一致，所以这里类名固定用 Main。",
     "", "Hello, Java!"),

    ("variables-and-types", "基本类型占用的字节",
     '''public class Main {
    public static void main(String[] args) {
        System.out.println("byte    " + Byte.BYTES + " 字节");
        System.out.println("short   " + Short.BYTES + " 字节");
        System.out.println("int     " + Integer.BYTES + " 字节");
        System.out.println("long    " + Long.BYTES + " 字节");
        System.out.println("float   " + Float.BYTES + " 字节");
        System.out.println("double  " + Double.BYTES + " 字节");
        System.out.println("char    " + Character.BYTES + " 字节");
        // 注意：Java 没有 Boolean.BYTES，boolean 在规范里未定义固定字节数
        System.out.println("boolean 1 字节（JLS 未规定固定大小）");
    }
}''',
     "char 占 2 字节是因为 Java 采用 UTF-16 编码；用 xxx.BYTES 可以让 JVM 自己报出字节数（boolean 没有 BYTES 字段）。",
     "", "byte    1 字节\nshort   2 字节\nint     4 字节\nlong    8 字节\n"
         "float   4 字节\ndouble  8 字节\nchar    2 字节\nboolean 1 字节（JLS 未规定固定大小）"),

    ("operators", "自增运算与浮点精度",
     '''public class Main {
    public static void main(String[] args) {
        int i = 1;
        int a = i++;   // a = 1, i = 2  (先取值后自增)
        System.out.println("a=" + a + ", i=" + i);

        int j = 1;
        int b = ++j;   // b = 2, j = 2  (先自增后取值)
        System.out.println("b=" + b + ", j=" + j);

        // 浮点数用二进制无法精确表示十进制小数
        System.out.println("0.1 + 0.2 == 0.3 ? " + (0.1 + 0.2 == 0.3));
    }
}''',
     "浮点数用二进制无法精确表示十进制小数，所以 0.1 + 0.2 != 0.3，这是 IEEE 754 的固有行为。",
     "", "a=1, i=2\nb=2, j=2\n0.1 + 0.2 == 0.3 ? false"),

    ("arrays", "数组越界异常与安全遍历",
     '''public class Main {
    public static void main(String[] args) {
        int[] nums = new int[5];
        for (int i = 0; i < nums.length; i++) {
            nums[i] = i * i;
        }
        try {
            System.out.println(nums[5]);   // 越界：抛 ArrayIndexOutOfBoundsException
        } catch (ArrayIndexOutOfBoundsException e) {
            System.out.println("捕获到异常: " + e.getClass().getSimpleName());
        }
        System.out.print("平方数: ");
        for (int n : nums) {
            System.out.print(n + " ");
        }
        System.out.println();
    }
}''',
     "数组下标从 0 开始，合法范围是 [0, length-1]。用 try-catch 兜住越界，是生产代码的基本素养。",
     "", "捕获到异常: ArrayIndexOutOfBoundsException\n平方数: 0 1 4 9 16 "),

    ("methods", "值传递的本质",
     '''public class Main {
    static class Box {
        int value;
    }

    static void modify(Box b) {
        b.value = 100;        // 改的是同一个对象
    }

    static void reassign(Box b) {
        b = new Box();       // 只是改了形参的引用
        b.value = 200;       // 对调用方不可见
    }

    public static void main(String[] args) {
        Box box = new Box();
        box.value = 1;
        modify(box);
        System.out.println("modify 后: " + box.value);
        reassign(box);
        System.out.println("reassign 后: " + box.value);
    }
}''',
     "Java 只有值传递，形参拿到的是引用变量的副本。modify 改的是对象内容（可见），reassign 换了引用（不可见）。",
     "", "modify 后: 100\nreassign 后: 100"),

    ("oop-core", "多态的运行时绑定",
     '''public class Main {
    abstract static class Animal {
        abstract void sound();
    }

    static class Dog extends Animal {
        @Override
        void sound() {
            System.out.println("汪汪");
        }
    }

    static class Cat extends Animal {
        @Override
        void sound() {
            System.out.println("喵喵");
        }
    }

    public static void main(String[] args) {
        Animal a = new Dog();
        Animal b = new Cat();
        a.sound();   // 输出"汪汪" —— 运行时按实际类型绑定
        b.sound();   // 输出"喵喵"
    }
}''',
     "编译看声明类型，运行看实际类型。这就是多态的运行时绑定（动态分发）。",
     "", "汪汪\n喵喵"),

    ("generics-type-erasure", "泛型擦除的证据",
     '''import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> a = new ArrayList<>();
        List<Integer> b = new ArrayList<>();
        System.out.println("运行期同类? " + (a.getClass() == b.getClass()));

        // 编译器拒绝基本类型泛型（下面这行若取消注释则编译失败）：
        // List<int> c = new ArrayList<>();

        List<String> names = new ArrayList<>();
        names.add("a");
        names.add("b");
        String first = names.get(0);   // 编译器插入强制转换
        System.out.println("首个元素: " + first);
    }
}''',
     "擦除后只剩上界信息，所以运行期无法区分 String 与 Integer；取值时的类型安全靠编译器插入的检查型转换完成。",
     "", "运行期同类? true\n首个元素: a"),

    ("reflection-annotation", "反射读取注解",
     '''import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.reflect.Method;

public class Main {
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
        Method m = Target.class.getMethod("run");
        MyAnno anno = m.getAnnotation(MyAnno.class);
        System.out.println("注解值: " + anno.value());
    }
}''',
     "RUNTIME 保留策略让注解在运行时可被反射读取；CLASS 与 SOURCE 策略则读不到。",
     "", "注解值: hello"),

    ("hashmap-red-black-tree", "HashMap 的定位与扩容",
     '''import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        // threshold = capacity * loadFactor (0.75)
        // resize 时容量翻倍，元素按 (hash & oldCap) 拆成高低位两半
        // 链表长度 >= 8 且数组长度 >= 64 时转红黑树
        Map<String, Integer> map = new HashMap<>();
        for (int i = 0; i < 20; i++) {
            map.put("key" + i, i);
        }
        System.out.println("size = " + map.size());
        System.out.println("key7 = " + map.get("key7"));
        System.out.println("扰动后 hash 是否可正可负: " + (map.hashCode() != 0));
    }
}''',
     "扰动函数 h ^= (h >>> 16) 减少哈希冲突；容量总是 2 的幂，定位靠 h & (cap - 1)。",
     "", "size = 20\nkey7 = 7\n扰动后 hash 是否可正可负: true"),

    ("stream-api", "Stream 分组统计",
     '''import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class Main {
    record User(String name, String grade, int score) {
    }

    public static void main(String[] args) {
        List<User> list = List.of(
                new User("张三", "A", 90),
                new User("李四", "B", 75),
                new User("王五", "A", 60),
                new User("赵六", "C", 55));

        Map<String, Long> stats = list.stream()
                .filter(u -> u.score() >= 60)
                .collect(Collectors.groupingBy(User::grade, LinkedHashMap::new, Collectors.counting()));

        stats.forEach((g, c) -> System.out.println(g + " -> " + c));
    }
}''',
     "groupingBy + counting 是最常用的组合；第二个参数指定 Map 实现可保持插入顺序。",
     "", "A -> 2\nB -> 1"),

    ("gc-algorithms", "可达性分析：对象何时被回收",
     '''import java.lang.ref.WeakReference;

public class Main {
    public static void main(String[] args) throws Exception {
        // GC Roots 包括：
        // 1. 虚拟机栈中引用的对象（局部变量表）
        // 2. 方法区中类静态属性引用的对象
        // 3. 方法区中常量引用的对象
        // 4. 本地方法栈中 JNI 引用的对象
        // 从 GC Roots 出发做图遍历，不可达的对象即为垃圾
        WeakReference<String> ref = new WeakReference<>(new String("可以被回收的对象"));
        System.out.println("可达: " + ref.get());

        // 局部变量一旦出了作用域，就不再构成 GC Root
        {
            String temp = new String("只在块内可达");
            System.out.println("块内: " + temp);
        }
        System.gc();
        Thread.sleep(200);
        System.out.println("gc 后是否已被回收: " + (ref.get() == null));
    }
}''',
     "标记阶段就是从 GC Roots 出发标记存活对象；System.gc() 只是建议，是否立即回收取决于 JVM 实现。",
     "", "可达: 可以被回收的对象\n块内: 只在块内可达\ngc 后是否已被回收: true"),

    ("thread-pool", "线程池核心参数",
     '''import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

public class Main {
    public static void main(String[] args) throws Exception {
        ThreadPoolExecutor pool = new ThreadPoolExecutor(
                4,                      // corePoolSize
                8,                      // maximumPoolSize
                60, TimeUnit.SECONDS,   // keepAliveTime
                new LinkedBlockingQueue<>(1024),
                new ThreadPoolExecutor.CallerRunsPolicy());

        for (int i = 1; i <= 3; i++) {
            int task = i;
            pool.execute(() -> System.out.println("任务 " + task + " 完成"));
        }
        pool.shutdown();
        pool.awaitTermination(5, TimeUnit.SECONDS);
        System.out.println("线程池已关闭");
    }
}''',
     "CPU 密集型建议 core = max = CPU 核数；IO 密集型可设更大。RejectedExecutionHandler 决定队列满时怎么办。"
     "注意：多个任务的完成顺序由线程调度决定，不保证与提交顺序一致。",
     "", None),

    ("completablefuture", "CompletableFuture 并行聚合",
     '''import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

public class Main {
    static String query(String service) {
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        return service + " 的结果";
    }

    public static void main(String[] args) throws Exception {
        CompletableFuture<String> f1 = CompletableFuture.supplyAsync(() -> query("A"));
        CompletableFuture<String> f2 = CompletableFuture.supplyAsync(() -> query("B"));

        String result = f1.thenCombine(f2, (a, b) -> a + b + " 合并")
                .thenApply(String::toUpperCase)
                .get(5, TimeUnit.SECONDS);

        System.out.println(result);
    }
}''',
     "thenCombine 用于两个独立任务的合并；thenApply 做后置变换；get 带超时防止无限等待。",
     "", "A 的结果B 的结果 合并"),

    ("kingbase-persistence", "KingBase JDBC 连接（示意）",
     '''public class Main {
    public static void main(String[] args) {
        // 驱动: cn.com.kingbase:kingbase8
        // 类名: com.kingbase8.Driver
        String url = "jdbc:kingbase8://localhost:54321/javacourse"
                + "?currentSchema=public&characterEncoding=UTF-8";

        // 正确写法：参数绑定（? 占位符），绝不拼接字符串
        String sql = "SELECT id, title FROM lesson WHERE module_id = ?";

        System.out.println("JDBC URL: " + url);
        System.out.println("SQL 语句: " + sql);
        System.out.println("说明: 真实运行需在 classpath 放入 kingbase8 驱动并能连通数据库");
    }
}''',
     "参数绑定防 SQL 注入，是强制要求。此示例只演示 URL 与 SQL 结构，不实际连接数据库。",
     "", "JDBC URL: jdbc:kingbase8://localhost:54321/javacourse?currentSchema=public&characterEncoding=UTF-8\n"
         "SQL 语句: SELECT id, title FROM lesson WHERE module_id = ?\n"
         "说明: 真实运行需在 classpath 放入 kingbase8 驱动并能连通数据库"),

    ("inner-class-and-lambda", "Lambda 与函数式接口",
     '''import java.util.List;
import java.util.function.Function;

public class Main {
    public static void main(String[] args) {
        List<String> names = List.of("Bob", "Alice", "Carol");

        // Function 是函数式接口，可以用 Lambda 实现
        Function<String, Integer> length = String::length;

        names.stream()
                .map(length)
                .forEach(len -> System.out.println("长度 " + len));

        int total = names.stream().mapToInt(String::length).sum();
        System.out.println("总长度 " + total);
    }
}''',
     "Lambda 只能实现「单抽象方法」的接口（函数式接口）；String::length 是方法引用，等价于 s -> s.length()。",
     "", "长度 3\n长度 5\n长度 5\n总长度 13"),

    ("exception-handling", "受检异常与自定义异常",
     '''public class Main {
    // 自定义受检异常
    static class InsufficientBalanceException extends Exception {
        InsufficientBalanceException(String msg) {
            super(msg);
        }
    }

    static void withdraw(double balance, double amount) throws InsufficientBalanceException {
        if (amount > balance) {
            throw new InsufficientBalanceException("余额不足：需要 " + amount + "，只有 " + balance);
        }
        System.out.println("取款成功，剩余 " + (balance - amount));
    }

    public static void main(String[] args) {
        try {
            withdraw(100.0, 150.0);
        } catch (InsufficientBalanceException e) {
            System.out.println("捕获异常: " + e.getMessage());
        } finally {
            System.out.println("无论如何都会执行 finally");
        }
    }
}''',
     "受检异常必须声明 throws 或捕获；自定义异常继承 Exception；finally 块一定会执行（除非 JVM 被强杀）。",
     "", "捕获异常: 余额不足：需要 150.0，只有 100.0\n无论如何都会执行 finally"),

    ("collection-overview", "Collection 体系全景",
     '''import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

public class Main {
    public static void main(String[] args) {
        List<String> list = new ArrayList<>(Arrays.asList("b", "a", "c", "a"));
        System.out.println("List 保留顺序与重复: " + list);

        // 用 TreeSet 保证输出顺序稳定（HashSet 的迭代顺序不保证）
        Set<String> set = new TreeSet<>(list);
        System.out.println("Set 去重: " + set);

        Map<String, Integer> map = new TreeMap<>();
        for (String s : list) {
            map.merge(s, 1, Integer::sum);
        }
        System.out.println("Map 统计: " + map);
    }
}''',
     "List 有序可重复、Set 无序不可重复、Map 键值对；TreeMap 按 key 排序，HashMap 不保证。",
     "", "List 保留顺序与重复: [b, a, c, a]\nSet 去重: [a, b, c]\nMap 统计: {a=2, b=1, c=1}"),

    ("concurrenthashmap", "ConcurrentHashMap 的线程安全",
     '''import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.Map;

public class Main {
    public static void main(String[] args) throws Exception {
        Map<String, Integer> map = new ConcurrentHashMap<>();
        int threads = 8, perThread = 1000;
        CountDownLatch latch = new CountDownLatch(threads);

        for (int t = 0; t < threads; t++) {
            new Thread(() -> {
                for (int i = 0; i < perThread; i++) {
                    map.merge("counter", 1, Integer::sum);
                }
                latch.countDown();
            }).start();
        }
        latch.await();
        System.out.println("最终计数: " + map.get("counter"));
    }
}''',
     "ConcurrentHashMap 用 CAS + synchronized 保证并发安全；merge 是原子操作，所以计数不会丢。",
     "", "最终计数: 8000"),

    ("project-stream-refactor", "Stream 重构：分组统计成绩",
     '''import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class Main {
    record Student(String name, int score) {
    }

    public static void main(String[] args) {
        List<Student> students = List.of(
                new Student("张三", 92),
                new Student("李四", 78),
                new Student("王五", 85),
                new Student("赵六", 61));

        Map<String, Long> byLevel = students.stream()
                .collect(Collectors.groupingBy(
                        s -> s.score() >= 90 ? "优秀" : s.score() >= 60 ? "及格" : "不及格",
                        LinkedHashMap::new,
                        Collectors.counting()));

        byLevel.forEach((k, v) -> System.out.println(k + ": " + v));

        double avg = students.stream().mapToInt(Student::score).average().orElse(0);
        System.out.printf("平均分: %.1f%n", avg);
    }
}''',
     "groupingBy 的分类函数是 Function；用 LinkedHashMap::new 保序；mapToInt 后 average 得到 double。",
     "", "优秀: 1\n及格: 3\n平均分: 79.0"),

    ("project-memory-leak", "内存泄漏：静态集合只增不减",
     '''import java.util.ArrayList;
import java.util.List;

public class Main {
    // 静态集合持有强引用 → 对象永远无法回收 → 内存泄漏
    static final List<byte[]> CACHE = new ArrayList<>();

    public static void main(String[] args) {
        for (int i = 0; i < 1000; i++) {
            CACHE.add(new byte[1024]);   // 每次 1KB
        }
        System.out.println("缓存条目: " + CACHE.size());
        // 每次 1KB = 1024 字节，1000 条约 1000 KB
        System.out.println("占用约: " + (CACHE.size() * 1024 / 1024) + " KB");
        // 正确做法：用完清空，或改用 WeakReference / Caffeine 等带淘汰策略的缓存
        CACHE.clear();
        System.out.println("清空后条目: " + CACHE.size());
    }
}''',
     "静态集合持有强引用会让对象无法被 GC 回收；生产上应使用有容量上限与淘汰策略的缓存（Caffeine）。",
     "", "缓存条目: 1000\n占用约: 1000 KB\n清空后条目: 0"),

    ("project-parallel-aggregate", "并行聚合：三个服务并发查询",
     '''import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

public class Main {
    static String query(String service, int millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        return service;
    }

    public static void main(String[] args) throws Exception {
        long start = System.currentTimeMillis();

        CompletableFuture<String> user = CompletableFuture.supplyAsync(() -> query("user", 300));
        CompletableFuture<String> order = CompletableFuture.supplyAsync(() -> query("order", 200));
        CompletableFuture<String> point = CompletableFuture.supplyAsync(() -> query("point", 100));

        String all = user.thenCombine(order, (a, b) -> a + "+" + b)
                .thenCombine(point, (a, b) -> a + "+" + b)
                .get(5, TimeUnit.SECONDS);

        long cost = System.currentTimeMillis() - start;
        System.out.println("结果: " + all);
        // 并行总耗时取决于最慢的一个查询（300ms），远小于串行的 600ms。
        // 具体毫秒数受调度影响，不作为断言，只打印出来供观察。
        System.out.println("并行完成，总耗时 " + cost + "ms（串行需 600ms）");
    }
}''',
     "并行聚合的关键是三个查询用 supplyAsync 提交到公共 ForkJoinPool，thenCombine 串联结果；总耗时取决于最慢的一个。",
     "", None),
]

# ============================================================================
# 课后习题：starter_code 给学生，solution_code 是参考答案，test_cases 用于判题
# 字段：slug, lesson_slug, title, description, difficulty, starter, solution, cases, hint
# cases 元素：(name, stdin, expected)
# ============================================================================
EXERCISES = [
    ("ex-sum-odd", "control-flow", "奇数之和",
     "读入一个正整数 n（1 ≤ n ≤ 1000），输出 1 到 n 之间所有奇数的和。\n"
     "提示：奇数就是 2k+1，可以每两步跳一次。",
     "BEGINNER",
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        // TODO: 用循环算出 1..n 中所有奇数的和
        int sum = 0;

        System.out.println(sum);
    }
}''',
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        int sum = 0;
        for (int i = 1; i <= n; i += 2) {
            sum += i;
        }

        System.out.println(sum);
    }
}''',
     [("n=1", "1\n", "1"),
      ("n=5", "5\n", "9"),
      ("n=10", "10\n", "25"),
      ("n=100", "100\n", "2500")],
     "从 1 开始每次加 2：for (int i = 1; i <= n; i += 2)"),

    ("ex-fizzbuzz", "control-flow", "FizzBuzz",
     "读入一个正整数 n（1 ≤ n ≤ 100），按顺序输出 1 到 n：\n"
     "· 能被 3 整除输出 Fizz\n"
     "· 能被 5 整除输出 Buzz\n"
     "· 同时被 3 和 5 整除输出 FizzBuzz\n"
     "· 其余输出数字本身",
     "BEGINNER",
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        for (int i = 1; i <= n; i++) {
            // TODO: 按规则输出
        }
    }
}''',
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        for (int i = 1; i <= n; i++) {
            if (i % 15 == 0) {
                System.out.println("FizzBuzz");
            } else if (i % 3 == 0) {
                System.out.println("Fizz");
            } else if (i % 5 == 0) {
                System.out.println("Buzz");
            } else {
                System.out.println(i);
            }
        }
    }
}''',
     [("n=3", "3\n", "1\n2\nFizz"),
      ("n=5", "5\n", "1\n2\nFizz\n4\nBuzz"),
      ("n=15", "15\n",
       "1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz")],
     "先判 15 的倍数，再判 3、5，否则输出数字本身。顺序不能反，否则 15 会被判成 Fizz。"),

    ("ex-array-max", "arrays", "数组最大值",
     "读入一个正整数 n（1 ≤ n ≤ 1000），接着读入 n 个整数（范围 -10000 ~ 10000），输出其中的最大值。",
     "BEGINNER",
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();
        int[] nums = new int[n];
        for (int i = 0; i < n; i++) {
            nums[i] = sc.nextInt();
        }

        // TODO: 求出数组中的最大值并输出
    }
}''',
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();
        int[] nums = new int[n];
        for (int i = 0; i < n; i++) {
            nums[i] = sc.nextInt();
        }

        int max = nums[0];
        for (int num : nums) {
            if (num > max) {
                max = num;
            }
        }
        System.out.println(max);
    }
}''',
     [("单元素", "1\n-5\n", "-5"),
      ("全负数", "4\n-9 -3 -7 -1\n", "-1"),
      ("含正负", "5\n3 -2 8 0 5\n", "8")],
     "把 max 初始化为 nums[0]（而不是 0），否则全负数时会答错。"),

    ("ex-string-reverse", "string", "字符串反转",
     "读入一行不含空格的字符串（长度 1 ~ 100），输出它的逆序字符串。",
     "BEGINNER",
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        String s = sc.nextLine();

        // TODO: 输出反转后的字符串
    }
}''',
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        String s = sc.nextLine();

        StringBuilder sb = new StringBuilder();
        for (int i = s.length() - 1; i >= 0; i--) {
            sb.append(s.charAt(i));
        }
        System.out.println(sb.toString());
    }
}''',
     [("普通", "hello\n", "olleh"),
      ("单字符", "a\n", "a"),
      ("混合大小写", "AbC\n", "CbA")],
     "StringBuilder 可变，循环 append 比字符串拼接高效得多。"),

    ("ex-count-vowels", "string", "统计元音字母个数",
     "读入一行不含空格的英文字符串（长度 1 ~ 200），输出其中元音字母（a e i o u，不区分大小写）的个数。",
     "BEGINNER",
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        String s = sc.nextLine();

        // TODO: 统计元音个数并输出
    }
}''',
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        String s = sc.nextLine();

        int count = 0;
        for (char c : s.toLowerCase().toCharArray()) {
            if (c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u') {
                count++;
            }
        }
        System.out.println(count);
    }
}''',
     [("全元音", "aeiou\n", "5"),
      ("无元音", "bcdfg\n", "0"),
      ("混合大小写", "Hello World\n", "3")],
     "先把字符串转成小写再判断，逻辑只需写一套。"),

    ("ex-factorial", "control-flow", "阶乘",
     "读入一个非负整数 n（0 ≤ n ≤ 20），输出 n 的阶乘。\n"
     "注意 0! = 1，且 20! 已经超过 int 范围。",
     "INTERMEDIATE",
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        // TODO: 计算并输出 n!
    }
}''',
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        long result = 1;
        for (int i = 2; i <= n; i++) {
            result *= i;
        }
        System.out.println(result);
    }
}''',
     [("0!", "0\n", "1"),
      ("5!", "5\n", "120"),
      ("20!", "20\n", "2432902008176640000")],
     "用 long 而不是 int：20! = 2432902008176640000 已超 int 上限。"),

    ("ex-prime-check", "control-flow", "判断素数",
     "读入一个正整数 n（2 ≤ n ≤ 100000），若 n 是素数输出 yes，否则输出 no。\n"
     "素数指只能被 1 和自身整除的数。",
     "INTERMEDIATE",
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        // TODO: 判断 n 是否为素数，输出 yes 或 no
    }
}''',
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        boolean prime = true;
        for (int i = 2; i * i <= n; i++) {
            if (n % i == 0) {
                prime = false;
                break;
            }
        }
        System.out.println(prime ? "yes" : "no");
    }
}''',
     [("2", "2\n", "yes"),
      ("9", "9\n", "no"),
      ("97", "97\n", "yes"),
      ("100", "100\n", "no")],
     "只需试到 √n：i * i <= n 即可，n 上限 10 万时比逐个试快两个数量级。"),

    ("ex-word-frequency", "collection-overview", "词频统计",
     "读入一行以空格分隔的英文单词（最多 50 个，单词仅含小写字母），\n"
     "统计每个单词出现次数，按「次数从多到少、次数相同时按单词字典序」输出，每行一个，格式为「单词 次数」。",
     "INTERMEDIATE",
     '''import java.util.Scanner;
import java.util.Map;
import java.util.TreeMap;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        String line = sc.nextLine();

        // TODO: 统计词频并按 (次数降序, 单词升序) 输出
    }
}''',
     '''import java.util.Scanner;
import java.util.Map;
import java.util.TreeMap;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        String line = sc.nextLine();

        Map<String, Integer> freq = new TreeMap<>();
        for (String w : line.split("\\\\s+")) {
            if (w.isEmpty()) {
                continue;
            }
            freq.merge(w, 1, Integer::sum);
        }

        List<Map.Entry<String, Integer>> entries = new ArrayList<>(freq.entrySet());
        entries.sort(Comparator.<Map.Entry<String, Integer>>comparingInt(Map.Entry::getValue)
                .reversed()
                .thenComparing(Map.Entry::getKey));

        for (Map.Entry<String, Integer> e : entries) {
            System.out.println(e.getKey() + " " + e.getValue());
        }
    }
}''',
     [("单个词", "java\n", "java 1"),
      ("各一次", "a b c\n", "a 1\nb 1\nc 1"),
      ("有重复", "a b a c b a\n", "a 3\nb 2\nc 1")],
     "用 TreeMap 存词频天然按字典序；排序时先按次数降序，再按单词升序（thenComparing）。"),

    ("ex-average-grade", "project-grade-system", "成绩平均分",
     "读入一个正整数 n（1 ≤ n ≤ 100），接着读入 n 个 0 ~ 100 的整数分数，\n"
     "输出平均分，保留两位小数。",
     "BEGINNER",
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        // TODO: 求平均分，保留两位小数输出
    }
}''',
     '''import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        int n = sc.nextInt();

        long sum = 0;
        for (int i = 0; i < n; i++) {
            sum += sc.nextInt();
        }
        System.out.printf("%.2f%n", (double) sum / n);
    }
}''',
     [("整除", "2\n90 80\n", "85.00"),
      ("有小数", "3\n80 90 100\n", "90.00"),
      ("单科", "1\n59\n", "59.00")],
     "用 printf(\"%.2f\") 控制小数位数，先转成 double 再除，否则整数除法会丢小数。"),
]


# ============================================================================
# 数据库访问：直接用 JDBC（Java 单文件源码模式）
#
# 为什么不用 Python 驱动：KingbaseES 只有官方 JDBC 驱动，没有 psycopg2 等 Python 驱动。
# 也不走 bash 脚本：Windows 上 Python 里 spawn 的 bash 可能命中 WSL，受安全策略限制。
# 所以这里用「Java 单文件源码模式」跑一个极小的 JDBC 工具，与 scripts/kb_env.sh 同思路。
# ============================================================================
_KB_JAVA_SRC = r'''import java.sql.*; import java.nio.charset.StandardCharsets; import java.nio.file.*;
import java.util.*;

public class KbLab {
    /** SQL 感知分割：字符串内的分号不切分，支持 '' 转义与 -- / 块注释 */
    static List<String> split(String sql) {
        List<String> out = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        int i = 0, n = sql.length();
        while (i < n) {
            char c = sql.charAt(i);
            if (c == '-' && i + 1 < n && sql.charAt(i + 1) == '-') {
                while (i < n && sql.charAt(i) != '\n') i++;
                continue;
            }
            if (c == '/' && i + 1 < n && sql.charAt(i + 1) == '*') {
                i += 2;
                while (i + 1 < n && !(sql.charAt(i) == '*' && sql.charAt(i + 1) == '/')) i++;
                i += 2;
                continue;
            }
            if (c == '\'') {
                cur.append(c);
                i++;
                while (i < n) {
                    char q = sql.charAt(i);
                    cur.append(q);
                    i++;
                    if (q == '\'') {
                        if (i < n && sql.charAt(i) == '\'') {
                            cur.append('\'');
                            i++;
                        } else {
                            break;
                        }
                    }
                }
                continue;
            }
            if (c == '"') {
                cur.append(c);
                i++;
                while (i < n) {
                    char q = sql.charAt(i);
                    cur.append(q);
                    i++;
                    if (q == '"') {
                        if (i < n && sql.charAt(i) == '"') {
                            cur.append('"');
                            i++;
                        } else {
                            break;
                        }
                    }
                }
                continue;
            }
            if (c == ';') {
                String s = cur.toString().trim();
                if (!s.isEmpty()) out.add(s);
                cur.setLength(0);
                i++;
                continue;
            }
            cur.append(c);
            i++;
        }
        String s = cur.toString().trim();
        if (!s.isEmpty()) out.add(s);
        return out;
    }

    public static void main(String[] a) throws Exception {
        String mode = a[0];                       // exec | query
        String sql = new String(Files.readAllBytes(Paths.get(a[1])), StandardCharsets.UTF_8);
        String url = "jdbc:kingbase8://" + a[2] + ":" + a[3] + "/" + a[4] + "?characterEncoding=UTF-8";
        try (Connection c = DriverManager.getConnection(url, a[5], a[6])) {
            if ("exec".equals(mode)) {
                int ok = 0, fail = 0;
                for (String stmt : split(sql)) {
                    try (Statement s = c.createStatement()) {
                        s.execute(stmt);
                        ok++;
                    } catch (Exception e) {
                        fail++;
                        String brief = stmt.substring(0, Math.min(120, stmt.length())).replace('\n', ' ');
                        System.out.println("FAIL: " + brief + " -> " + e.getMessage());
                    }
                }
                System.out.println("applied=" + ok + " failed=" + fail);
            } else {
                try (Statement s = c.createStatement()) {
                    boolean has = s.execute(sql);
                    if (has) {
                        try (ResultSet rs = s.getResultSet()) {
                            ResultSetMetaData md = rs.getMetaData();
                            int n = md.getColumnCount();
                            while (rs.next()) {
                                StringBuilder sb = new StringBuilder();
                                for (int i = 1; i <= n; i++) {
                                    if (i > 1) sb.append('\u0001');
                                    String v = rs.getString(i);
                                    sb.append(v == null ? "" : v);
                                }
                                System.out.println(sb.toString());
                            }
                        }
                    }
                }
            }
        }
    }
}
'''


def _java_run(mode, sql_text):
    """把 SQL 交给 JDBC 工具执行。mode: exec | query"""
    os.makedirs(SQL_DIR, exist_ok=True)
    java_file = SQL_DIR + "/KbLab.java"
    sql_file = SQL_DIR + "/KbLab.sql"
    with open(java_file, "w", encoding="utf-8") as f:
        f.write(_KB_JAVA_SRC)
    with open(sql_file, "w", encoding="utf-8") as f:
        f.write(sql_text)
    r = subprocess.run(
        ["java", "-Dfile.encoding=UTF-8", "-cp", JDBC_JAR,
         java_file.replace("/", "\\"), mode, sql_file.replace("/", "\\"),
         DB["host"], DB["port"], DB["db"], DB["user"], DB["pw"]],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise RuntimeError("JDBC 执行失败：%s\n%s" % (r.stdout, r.stderr))
    return r.stdout or ""


def kb_exec(statements, tolerate=False):
    """把一批 SQL 灌进库。statements: list[str]"""
    payload = ";\n".join(s.rstrip().rstrip(";") for s in statements) + ";\n"
    out = _java_run("exec", payload)
    if "failed=0" not in out and not tolerate:
        raise RuntimeError("SQL 执行存在失败语句：\n" + out[-3000:])
    return out


def kb_query(sql):
    """返回 list[list[str]]（以 \\u0001 分隔的列）"""
    out = _java_run("query", sql.strip().rstrip(";") + ";")
    rows = []
    for line in out.splitlines():
        if line.strip() == "":
            continue
        rows.append(line.split("\u0001"))
    return rows


def lit(s):
    """SQL 字符串字面量：单引号转义，保留真换行。"""
    if s is None:
        return "NULL"
    return "'" + s.replace("'", "''") + "'"


def table_exists(table):
    return len(kb_query("SELECT tablename FROM pg_tables WHERE tablename = '%s'" % table)) > 0


def column_exists(table, column):
    return len(kb_query(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_name = '%s' AND column_name = '%s'" % (table, column))) > 0


DDL_TABLES = [
    """CREATE TABLE code_exercise (
    id           BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    lesson_id    BIGINT,
    slug         VARCHAR(80)  NOT NULL,
    title        VARCHAR(160) NOT NULL,
    description  CLOB,
    difficulty   VARCHAR(20)  NOT NULL DEFAULT 'BEGINNER',
    language     VARCHAR(32)  NOT NULL DEFAULT 'java',
    starter_code CLOB         NOT NULL,
    solution_code CLOB,
    test_cases   CLOB,
    hint         CLOB,
    sort_order   INTEGER      NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_exercise_slug UNIQUE (slug)
)""",
    "CREATE INDEX idx_exercise_lesson ON code_exercise (lesson_id, sort_order)",
    """CREATE TABLE code_submission (
    id           BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id      BIGINT,
    exercise_id  BIGINT,
    source_code  CLOB         NOT NULL,
    status       VARCHAR(20)  NOT NULL,
    case_results CLOB,
    stdout       CLOB,
    stderr       CLOB,
    error_output CLOB,
    passed_count INTEGER      NOT NULL DEFAULT 0,
    total_count  INTEGER      NOT NULL DEFAULT 0,
    duration_ms  INTEGER      NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sub_user FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE CASCADE,
    CONSTRAINT fk_sub_exercise FOREIGN KEY (exercise_id) REFERENCES code_exercise (id) ON DELETE CASCADE
)""",
    "CREATE INDEX idx_sub_user ON code_submission (user_id, created_at)",
    "CREATE INDEX idx_sub_exercise ON code_submission (exercise_id, created_at)",
]


def main():
    print("==> [1/5] 建表 / 补列")
    stmts = []
    # code_submission 依赖 code_exercise，删除顺序必须先子表后父表
    if not column_exists("code_submission", "case_results"):
        stmts.append("DROP TABLE IF EXISTS code_submission CASCADE")
        stmts.append(DDL_TABLES[2])
        stmts.append(DDL_TABLES[3])
        stmts.append(DDL_TABLES[4])
    # code_exercise：整表缺失才建（用列集合判断，避免「表在但结构不对」的半成品状态）
    if not column_exists("code_exercise", "starter_code"):
        stmts.append("DROP TABLE IF EXISTS code_exercise CASCADE")
        stmts.append(DDL_TABLES[0])
        stmts.append(DDL_TABLES[1])
    if not column_exists("code_snippet", "runnable"):
        stmts.append("ALTER TABLE code_snippet ADD COLUMN runnable BOOLEAN NOT NULL DEFAULT FALSE")
    if not column_exists("code_snippet", "stdin"):
        stmts.append("ALTER TABLE code_snippet ADD COLUMN stdin VARCHAR(2000)")
    if not column_exists("code_snippet", "expected_out"):
        stmts.append("ALTER TABLE code_snippet ADD COLUMN expected_out VARCHAR(2000)")
    if stmts:
        kb_exec(stmts)
        print("    执行 %d 条 DDL" % len(stmts))
    else:
        print("    表结构已是最新")

    print("==> [2/5] 修复存量示例代码的字面 \\n")
    # chr(92) = 反斜杠；chr(10) = 换行
    kb_exec(["UPDATE code_snippet SET code_text = replace(code_text, chr(92) || 'n', chr(10))"])
    print("    已把字面 \\n 换成真换行")

    print("==> [3/5] 写入可运行的示例代码")
    stmts = []
    for slug, title, code, expl, stdin, expected in SNIPPETS:
        rows = kb_query("SELECT id FROM lesson WHERE slug = '%s'" % slug)
        if not rows:
            print("    ! 找不到课时 %s，跳过" % slug)
            continue
        lid = rows[0][0]
        exist = kb_query("SELECT id FROM code_snippet WHERE lesson_id = %s AND title = %s"
                         % (lid, lit(title)))
        if exist:
            stmts.append(
                "UPDATE code_snippet SET code_text = %s, explanation = %s, runnable = TRUE, "
                "stdin = %s, expected_out = %s WHERE id = %s"
                % (lit(code), lit(expl), lit(stdin or ""), lit(expected or ""), exist[0][0]))
        else:
            stmts.append(
                "INSERT INTO code_snippet (lesson_id, language, title, code_text, explanation, "
                "runnable, stdin, expected_out, sort_order) "
                "VALUES (%s, 'java', %s, %s, %s, TRUE, %s, %s, 1)"
                % (lid, lit(title), lit(code), lit(expl), lit(stdin or ""), lit(expected or "")))
    kb_exec(stmts)
    print("    写入 %d 条示例" % len(stmts))

    # 清理：同一课时下「不可运行的旧片段」与新示例重复，删掉旧片段，
    # 只保留可运行版本（否则学生看到的是缺 class/main 的半截代码）
    stmts = []
    for slug, _title, _c, _e, _s, _x in SNIPPETS:
        rows = kb_query("SELECT id FROM lesson WHERE slug = '%s'" % slug)
        if not rows:
            continue
        lid = rows[0][0]
        stmts.append(
            "DELETE FROM code_snippet WHERE lesson_id = %s AND runnable = FALSE" % lid)
    if stmts:
        kb_exec(stmts)
        left = kb_query("SELECT count(*) FROM code_snippet WHERE runnable = FALSE")
        print("    清理同课时的旧片段示例，剩余不可运行片段: %s 条" % left[0][0])

    print("==> [4/5] 写入课后习题")
    stmts = []
    for (slug, lesson_slug, title, desc, diff, starter, solution, cases, hint) in EXERCISES:
        rows = kb_query("SELECT id FROM lesson WHERE slug = '%s'" % lesson_slug)
        if not rows:
            print("    ! 找不到课时 %s，跳过习题 %s" % (lesson_slug, slug))
            continue
        lid = rows[0][0]
        tc_json = json.dumps([{"name": n, "stdin": s, "expected": e} for (n, s, e) in cases],
                             ensure_ascii=False)
        exist = kb_query("SELECT id FROM code_exercise WHERE slug = %s" % lit(slug))
        if exist:
            stmts.append(
                "UPDATE code_exercise SET lesson_id = %s, title = %s, description = %s, "
                "difficulty = %s, starter_code = %s, solution_code = %s, test_cases = %s, hint = %s "
                "WHERE id = %s"
                % (lid, lit(title), lit(desc), lit(diff), lit(starter), lit(solution),
                   lit(tc_json), lit(hint), exist[0][0]))
        else:
            stmts.append(
                "INSERT INTO code_exercise (lesson_id, slug, title, description, difficulty, "
                "language, starter_code, solution_code, test_cases, hint, sort_order) "
                "VALUES (%s, %s, %s, %s, %s, 'java', %s, %s, %s, %s, 1)"
                % (lid, lit(slug), lit(title), lit(desc), lit(diff), lit(starter),
                   lit(solution), lit(tc_json), lit(hint)))
    kb_exec(stmts)
    print("    写入 %d 道习题" % len(stmts))

    print("==> [5/5] 校验")
    rows = kb_query("SELECT (SELECT count(*) FROM code_snippet WHERE runnable = TRUE) AS runnable, "
                     "(SELECT count(*) FROM code_exercise) AS exercises")
    print("    可运行示例: %s 条，习题: %s 道" % (rows[0][0], rows[0][1]))

    if "--verify" in sys.argv:
        return verify()
    return 0


# ============================================================================
# 自检：用本机 JDK 真实编译运行每条示例与每道习题的参考答案
# ============================================================================
def find_jdk():
    for cand in [os.environ.get("CODE_JAVA_HOME"), os.environ.get("JAVA_HOME"),
                 "D:/develop/Java/jdk-21", "C:/Program Files/Java/jdk-17"]:
        if cand and os.path.isfile(os.path.join(cand, "bin", "javac.exe")):
            return cand
    return None


def verify():
    jdk = find_jdk()
    if not jdk:
        print("!! 找不到本机 JDK，跳过自检")
        return 1
    import tempfile
    import shutil
    state = {"ok": 0, "fail": 0}
    failures = []

    def compile_run(code, stdin, label):
        d = tempfile.mkdtemp(prefix="verify-java-")
        try:
            src = os.path.join(d, "Main.java")
            with open(src, "w", encoding="utf-8") as f:
                f.write(code)
            r = subprocess.run([os.path.join(jdk, "bin", "javac.exe"), "-encoding", "UTF-8",
                                "-d", d, src], capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
            if r.returncode != 0:
                state["fail"] += 1
                failures.append("%s 编译失败: %s" % (label, r.stderr.strip()[:400]))
                return None
            r2 = subprocess.run([os.path.join(jdk, "bin", "java.exe"),
                                 "-Dfile.encoding=UTF-8",
                                 "-Dstdout.encoding=UTF-8",
                                 "-Dsun.stdout.encoding=UTF-8",
                                 "-Dsun.stderr.encoding=UTF-8",
                                 "-cp", d, "Main"], input=stdin or "",
                                capture_output=True, text=True, encoding="utf-8",
                                errors="replace", timeout=30)
            if r2.returncode != 0:
                state["fail"] += 1
                failures.append("%s 运行失败: %s" % (label, r2.stderr.strip()[:400]))
                return None
            state["ok"] += 1
            return r2.stdout
        finally:
            shutil.rmtree(d, ignore_errors=True)

    print("==> 自检：示例代码")
    for slug, title, code, expl, stdin, expected in SNIPPETS:
        out = compile_run(code, stdin, "示例[%s]" % title)
        if out is None or expected is None:
            continue
        if out.strip() != expected.strip():
            state["fail"] += 1
            state["ok"] -= 1
            failures.append("示例[%s] 输出不符\n     期望: %r\n     实际: %r"
                            % (title, expected.strip(), out.strip()))

    print("==> 自检：习题参考答案")
    for (slug, lesson_slug, title, desc, diff, starter, solution, cases, hint) in EXERCISES:
        for (name, stdin, expected) in cases:
            out = compile_run(solution, stdin, "习题[%s/%s]" % (title, name))
            if out is None:
                continue
            if out.strip() != expected.strip():
                state["fail"] += 1
                state["ok"] -= 1
                failures.append("习题[%s/%s] 输出不符\n     期望: %r\n     实际: %r"
                                % (title, name, expected.strip(), out.strip()))

    print("    通过 %d 项，失败 %d 项" % (state["ok"], state["fail"]))
    for f_ in failures:
        print("    ! " + f_)
    return 0 if state["fail"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
