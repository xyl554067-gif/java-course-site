-- ============================================================================
-- Java 课程介绍网站 — 种子数据
-- 卡通风格站点：Java 咖啡色系 + 鲸鲸 AI 助教
-- ============================================================================

INSERT INTO app_user (username, password_hash, salt, nickname, email, role, status) VALUES
('admin',  'PLACEHOLDER', 'PLACEHOLDER', '站长鲸鲸', 'admin@javacourse.local', 'ADMIN', 'active'),
('demo',   'PLACEHOLDER', 'PLACEHOLDER', '体验学员', 'demo@javacourse.local',  'student', 'active');

INSERT INTO course (slug, title, subtitle, description, instructor, version, difficulty, status, sort_order, total_lessons) VALUES
('java-mastery', 'Java 精通之路', '从 Hello World 到高并发架构的完整旅程',
 '用一条清晰的路径学完 Java：语言基础 → 面向对象 → 集合框架 → JVM 原理 → 并发编程 → 框架实战。每一节课都配可运行代码、原理剖析与随堂练习，学习进度自动保存。',
 '鲸鲸讲师团', 'v2.4', 'BEGINNER', 'PUBLISHED', 1, 42);

INSERT INTO course_module (course_id, title, summary, icon, sort_order, lesson_count) VALUES
(1, '语言起步：Hello Java', '变量、类型、流程控制，写出第一行可运行的 Java。', 'coffee',  1, 8),
(1, '面向对象乐园', '类与对象、继承多态、接口抽象，把现实世界搬进代码。', 'puzzle', 2, 10),
(1, '集合框架大观园', 'List、Map、Set 三大容器与泛型的类型擦除真相。', 'boxes',  3, 8),
(1, 'JVM 内部探险', '内存布局、GC 机制、类加载，把黑盒打开给你看。', 'compass',4, 7),
(1, '并发编程实验室', '线程池、锁机制、CompletableFuture，多线程不再靠猜。', 'rocket', 5, 6),
(1, '框架实战工坊', 'Spring Boot、MyBatis 与 KingBase 的企业级应用。', 'wrench', 6, 3);

INSERT INTO lesson (module_id, title, slug, summary, content, duration_min, difficulty, sort_order, is_preview, view_count) VALUES
(1, 'Hello World：第一行 Java', 'hello-world', '认识 JDK、编译与运行，一分钟跑起你的第一个程序。',
 '每个 Java 程序员都从这行代码开始。本节带你装好 JDK 17，用记事本写第一行输出，再用 javac 亲手编译它。你会理解 .class 文件是什么，以及为什么 Java 叫"一次编写，到处运行"。', 12, 'BEGINNER', 1, 1, 0),
(1, '变量与八大基本类型', 'variables-and-types', 'int、long、double、boolean……每个类型占多少字节？', 
 'Java 有 8 种基本类型和 1 种引用类型。我们用一张内存图讲清楚 int 与 long 的取值范围差异，以及为什么 char 是 16 位而不是 8 位。', 25, 'BEGINNER', 2, 1, 0),
(1, '运算符与表达式陷阱', 'operators', '自增运算符的左值右值、浮点精度与短路求值。',
 '`i++` 和 `++i` 到底差在哪？浮点数为什么 0.1 + 0.2 不等于 0.3？本节用字节码视角拆解这些面试高频陷阱。', 22, 'BEGINNER', 3, 0, 0),
(1, '流程控制：if、switch 与循环', 'control-flow', '分支与循环的写法、break 与 continue 的差别。',
 '从 if/else 到增强版 switch 再到 for-each，掌握分支控制的全部写法，并学会用 continue 优化批量处理逻辑。', 28, 'BEGINNER', 4, 0, 0),
(1, '数组与一维二维遍历', 'arrays', '数组初始化、边界检查与 Arrays 工具类的妙用。',
 '数组是引用类型，赋值即引用共享。讲清越界异常 ArrayIndexOutOfBoundsException 的产生时机，并演示 Arrays.stream 带来的优雅遍历。', 20, 'BEGINNER', 5, 0, 0),
(1, '流程控制实战：猜数字游戏', 'project-guess-number', '综合运用分支与循环，写一个可交互的小游戏。', 
 '把前面学的控制流串起来，从零实现一个带难度分级、次数限制和成绩评价的猜数字游戏。', 35, 'BEGINNER', 6, 0, 0),
(1, '字符串 String 详解', 'string', '不可变性、字符串常量池与 StringBuilder。', 
 'String 为什么设计成不可变？字符串常量池如何节省内存？为什么循环拼接一定用 StringBuilder？本节用图解讲透底层原理。', 30, 'INTERMEDIATE', 7, 0, 0),
(1, '方法与参数传递', 'methods', '值传递还是引用传递？一次讲清。', 
 'Java 只有值传递，没有引用传递。所谓"传对象"传的是引用的副本。配合内存图彻底终结这个经典误解。', 24, 'INTERMEDIATE', 8, 0, 0),

(2, '类与对象的诞生', 'class-and-object', '字段、方法、构造器与 this 关键字。', 
 '从一张类图开始，理解实例字段与静态字段的区别，掌握构造器链与 this 的两种用法。', 26, 'BEGINNER', 1, 1, 0),
(2, '封装、继承与多态', 'oop-core', '三大特性的关系与重写重载的区分。', 
 '继承是为了复用还是多态？重写(Override)与重载(Overload)到底差在哪？我们用一段可运行的代码证明多态的运行时绑定。', 34, 'INTERMEDIATE', 2, 0, 0),
(2, '接口与抽象类怎么选', 'interface-vs-abstract', '面向接口编程的实践准则。', 
 '什么时候用接口、什么时候用抽象类？我们给出一条可操作的判断准则，并演示 Java 8 默认方法如何化解多继承困境。', 28, 'INTERMEDIATE', 3, 0, 0),
(2, 'final、static 与不可变对象', 'final-static-immutable', '构建真正安全的不可变对象。', 
 '不可变对象的三板斧：final 字段、构造期间不泄漏 this、防御性拷贝。我们用 String 的实现逐条印证。', 25, 'INTERMEDIATE', 4, 0, 0),
(2, '枚举与 records', 'enum-and-record', '现代 Java 的两个省心利器。', 
 '枚举不只是常量集合，还自带抽象方法；record 让你一行定义一个不可变数据载体。两者都能大幅减少样板代码。', 22, 'INTERMEDIATE', 5, 0, 0),
(2, '内部类与 Lambda', 'inner-class-and-lambda', '四种内部类与函数式接口。', 
 '静态内部类、成员内部类、局部内部类、匿名内部类各有用武之地，再顺势过渡到 Lambda 表达式与方法引用。', 30, 'INTERMEDIATE', 6, 0, 0),
(2, '异常处理最佳实践', 'exception-handling', '受检异常、非受检异常与 try-with-resources。', 
 '什么时候该抛异常、什么时候该捕获？finally 的执行时机与 try-with-resources 的自动关闭机制，都要讲透。', 32, 'ADVANCED', 7, 0, 0),
(2, '泛型与类型擦除', 'generics-type-erasure', '为什么泛型不能用于基本类型？', 
 '编译器如何擦除类型参数？为什么 List<int> 不合法但 List<Integer> 合法？本节用字节码还原真相。', 32, 'ADVANCED', 8, 0, 0),
(2, '反射与注解入门', 'reflection-annotation', '运行时元编程的能力与代价。', 
 '反射让 Java 在运行时读取类信息，注解让元数据可被读取。理解它们能读懂 Spring 与 JUnit 的底层设计。', 36, 'ADVANCED', 9, 0, 0),
(2, '实战：设计一个学生成绩管理系统', 'project-grade-system', '综合运用 OOP 思想完成一个完整小项目。', 
 '需求分析 → 类设计 → 面向接口编程 → 集合存储 → 异常处理，完整走一遍 OOP 落地流程。', 45, 'ADVANCED', 10, 0, 0),

(3, 'Collection 体系全景图', 'collection-overview', 'List、Set、Map 三大分支的关系。', 
 '一张图看懂 Java 集合框架的继承结构，理解每个接口的设计意图，而不是死记硬背。', 20, 'INTERMEDIATE', 1, 0, 0),
(3, 'ArrayList 源码剖析', 'arraylist-source', '动态数组的扩容机制与复杂度。', 
 'add 元素背后发生了什么？size() 为什么能 O(1)？我们从源码逐行读懂 ArrayList 的扩容策略。', 38, 'ADVANCED', 2, 0, 0),
(3, 'HashMap 的红黑树', 'hashmap-red-black-tree', '桶、链表与树化阈值的完整逻辑。', 
 'HashMap 为什么查询是 O(1)？链表何时树化？resize 过程中元素如何迁移？逐一拆解。', 45, 'ADVANCED', 3, 0, 0),
(3, 'ConcurrentHashMap 与线程安全', 'concurrenthashmap', '分段锁到 CAS 的演进。', 
 'JDK8 之前的 Segment 分段锁与 JDK8 之后的 CAS + synchronized 有何不同？为什么并发扩容是安全的？', 42, 'ADVANCED', 4, 0, 0),
(3, 'Set 家族：HashSet 与 TreeSet', 'set-family', '元素唯一性的实现原理。', 
 'HashSet 底层就是 HashMap，TreeSet 底层是 TreeMap。讲清它们的排序与去重策略。', 24, 'INTERMEDIATE', 5, 0, 0),
(3, '迭代器与并发修改异常', 'iterator-cmc', '为什么 foreach 里删元素会抛异常？', 
 'fail-fast 机制到底在检测什么？CopyOnWriteArrayList 又是如何做到安全遍历的？', 26, 'ADVANCED', 6, 0, 0),
(3, 'Stream API 与函数式编程', 'stream-api', '声明式数据处理的威力。', 
 'map / filter / collect 三板斧，flatMap 与 Collectors.groupingBy 的分组统计，以及惰性求值的执行时机。', 40, 'ADVANCED', 7, 0, 0),
(3, '实战：用 Stream 重构数据处理', 'project-stream-refactor', '把一段 200 行的 for 循环改成 20 行 Stream。', 
 '选一个真实场景（旧报表统计），现场重构，展示 Stream 如何让意图更清晰。', 35, 'ADVANCED', 8, 0, 0),

(4, 'JVM 内存结构全景', 'jvm-memory', '堆、栈、方法区与程序计数器。', 
 '一张内存图讲清每个区域存什么、什么时候创建、什么时候回收。这是理解一切 JVM 问题的起点。', 30, 'INTERMEDIATE', 1, 0, 0),
(4, '对象在内存中的布局', 'object-layout', '对象头、实例数据与对齐填充。', 
 '为什么一个空 Object 占据 16 字节？压缩指针、字段重排与内存对齐，一个都不能少。', 35, 'ADVANCED', 2, 0, 0),
(4, '类加载机制全流程', 'class-loading', '加载、验证、准备、解析、初始化五阶段。', 
 '双亲委派模型保证类加载的安全，破坏双亲委派的场景又是什么？结合 SPI 实战讲解。', 38, 'ADVANCED', 3, 0, 0),
(4, '垃圾回收算法演进', 'gc-algorithms', '标记清除、复制、分代收集与 G1。', 
 '从根可达性分析讲起，理解各种 GC 算法的取舍，最终理解 G1 的 Region 模型与停顿预测。', 42, 'ADVANCED', 4, 0, 0),
(4, 'JVM 调优实战与工具链', 'jvm-tuning-tools', 'jstat、jmap、jstack 与 Arthas。', 
 '线上 OOM 怎么排查？用工具链定位内存泄漏与死锁，而不是靠猜。', 45, 'ADVANCED', 5, 0, 0),
(4, '类字节码结构解析', 'bytecode', 'class 文件的魔数、常量池与指令。', 
 '用 javap 反编译看懂 class 文件结构，理解"一次编写到处运行"在字节码层面的体现。', 40, 'ADVANCED', 6, 0, 0),
(4, '实战：JVM 内存泄漏定位', 'project-memory-leak', '一个真实 OOM 案例的完整排查过程。', 
 '从现象到假设到工具验证，完整走一遍生产环境内存问题的定位流程。', 50, 'ADVANCED', 7, 0, 0),

(5, '线程基础与生命周期', 'thread-basics', '创建、状态转换与中断机制。', 
 'Java 线程六种状态的转换图，中断机制为什么比 stop 更安全。', 25, 'INTERMEDIATE', 1, 0, 0),
(5, '锁机制：synchronized 与 Lock', 'lock-mechanisms', '对象头 Mark Word 与不同锁形态。', 
 '无锁、偏向锁、轻量级锁、重量级锁的升级路径，AQS 支撑的 ReentrantLock 优势在哪。', 40, 'ADVANCED', 2, 0, 0),
(5, '线程池的原理与调优', 'thread-pool', '七个参数与拒绝策略的取舍。', 
 '为什么线程池参数这样设？CPU 密集型与 IO 密集型的差异化配置，结合真实压测数据讲解。', 38, 'ADVANCED', 3, 0, 0),
(5, '并发容器与原子类', 'concurrent-collections', 'CAS、ABA 问题与 LongAdder。', 
 '从 Unsafe.compareAndSwap 讲到 AtomicLong 与 LongAdder 的分段累加优化。', 42, 'ADVANCED', 4, 0, 0),
(5, 'CompletableFuture 异步编排', 'completablefuture', '串行、并行、聚合与异常处理。', 
 'thenApply 与 thenCompose 的区别，allOf 与 anyOf 的用法，以及超时与兜底策略。', 35, 'ADVANCED', 5, 0, 0),
(5, '实战：并行聚合百万数据', 'project-parallel-aggregate', '多核并行计算与性能对比。', 
 '把串行聚合改造成并行，测量加速比，并分析什么时候并行反而更慢。', 48, 'ADVANCED', 6, 0, 0),

(6, 'Spring Boot 项目初始化', 'spring-boot-init', '依赖管理与自动装配原理。', 
 '从 start.spring.io 到本地跑通，理解 starter 与自动配置如何协同工作。', 30, 'INTERMEDIATE', 1, 0, 0),
(6, '用 KingBase 持久化数据', 'kingbase-persistence', '国产数据库接入实战。', 
 '使用 kingbase8 JDBC 驱动接入 KingbaseES V8，手写 DDL、配置连接池、验证增删改查。', 35, 'ADVANCED', 2, 0, 0),
(6, 'RESTful API 设计规范', 'restful-api', '资源建模、状态码与幂等性。', 
 '好的 API 设计让前端不用问后端就知道怎么调用。讲清资源命名、HTTP 方法语义与错误响应规范。', 32, 'INTERMEDIATE', 3, 0, 3890);

INSERT INTO code_snippet (lesson_id, language, title, code_text, explanation, sort_order) VALUES
(1, 'java', '第一个 Java 程序', 'public class HelloWorld {\n    public static void main(String[] args) {\n        System.out.println("Hello, Java!");\n    }\n}\n', 'javac 编译为 .class，再由 JVM 加载执行。', 1),
(2, 'java', '基本类型占用的字节', 'byte    1 字节  -128 ~ 127\nshort   2 字节  -32768 ~ 32767\nint     4 字节  约 ±21 亿\nlong    8 字节  约 ±922 亿亿\nfloat   4 字节  单精度\ndouble  8 字节  双精度\nchar    2 字节  Unicode 单字符\nboolean 1 字节  true / false', 'char 占 2 字节是因为 Java 采用 UTF-16 编码。', 1),
(3, 'java', '自增运算的差异', 'int i = 1;\nint a = i++;   // a = 1, i = 2  (先取值后自增)\nint j = 1;\nint b = ++j;   // b = 2, j = 2  (先自增后取值)\n\n// 浮点精度\nSystem.out.println(0.1 + 0.2 == 0.3);   // false!', '浮点数用二进制无法精确表示十进制小数。', 1),
(5, 'java', '数组越界异常', 'int[] nums = new int[5];\nSystem.out.println(nums[0]);   // 正常\nSystem.out.println(nums[5]);   // 抛出 ArrayIndexOutOfBoundsException\n\n// 安全的遍历\nfor (int n : nums) {\n    System.out.println(n);\n}', '数组下标从 0 开始，合法范围是 [0, length-1]。', 1),
(8, 'java', '值传递的本质', 'class Box { int value; }\n\nvoid modify(Box b) {\n    b.value = 100;        // 改的是同一个对象\n}\n\nvoid reassign(Box b) {\n    b = new Box();       // 只是改了形参的引用\n    b.value = 200;       // 对调用方不可见\n}', 'Java 只有值传递，形参拿到的是引用变量的副本。', 1),
(10, 'java', '多态的运行时绑定', 'abstract class Animal {\n    abstract void sound();\n}\n\nclass Dog extends Animal {\n    @Override void sound() { System.out.println("汪汪"); }\n}\n\nAnimal a = new Dog();\na.sound();   // 输出"汪汪" —— 运行时按实际类型绑定', '编译看声明类型，运行看实际类型。', 1),
(14, 'java', '泛型擦除的证据', 'List<String>  a = new ArrayList<>();\nList<Integer> b = new ArrayList<>();\nSystem.out.println(a.getClass() == b.getClass());   // true\n\n// 编译器拒绝基本类型泛型\n// List<int> c = new ArrayList<>();   // 编译错误', '擦除后只剩上界信息，所以无法区分 String 与 Integer。', 1),
(15, 'java', '反射读取注解', '@Retention(RetentionPolicy.RUNTIME)\n@interface MyAnno { String value(); }\n\nclass Target {\n    @MyAnno("hello")\n    public void run() {}\n}\n\nMethod m = Target.class.getMethod("run");\nMyAnno anno = m.getAnnotation(MyAnno.class);\nSystem.out.println(anno.value());   // hello', 'RUNTIME 保留策略让注解在运行时可被反射读取。', 1),
(19, 'java', 'HashMap 扩容逻辑', '// threshold = capacity * loadFactor (0.75)\n// resize 时容量翻倍，元素按 (hash & oldCap) 拆成高低位两半\n// 链表长度 >= 8 且数组长度 >= 64 时转红黑树\nint h = key.hashCode();\nh ^= (h >>> 16);              // 扰动函数，让高位也参与运算\nint index = h & (cap - 1);    // 定位桶', '扰动函数减少哈希冲突。', 1),
(22, 'java', 'Stream 分组统计', 'Map<String, Long> stats = list.stream()\n    .filter(u -> u.getScore() >= 60)\n    .collect(Collectors.groupingBy(\n        User::getGrade,\n        Collectors.counting()\n    ));', 'groupingBy + counting 是最常用的组合。', 1),
(26, 'java', '可达性分析', '// GC Roots 包括：\n// 1. 虚拟机栈中引用的对象（局部变量表）\n// 2. 方法区中类静态属性引用的对象\n// 3. 方法区中常量引用的对象\n// 4. 本地方法栈中 JNI 引用的对象\n//\n// 从 GC Roots 出发做图遍历，不可达的对象即为垃圾', '标记阶段就是从 GC Roots 出发标记存活对象。', 1),
(30, 'java', '线程池核心参数', 'ThreadPoolExecutor pool = new ThreadPoolExecutor(\n    4,                      // corePoolSize\n    8,                      // maximumPoolSize\n    60, TimeUnit.SECONDS,   // keepAliveTime\n    new LinkedBlockingQueue<>(1024),\n    new ThreadPoolExecutor.CallerRunsPolicy()\n);', 'CPU 密集型建议 core = max = CPU核数；IO 密集型可设更大。', 1),
(33, 'java', 'CompletableFuture 并行聚合', 'CompletableFuture<String> f1 = supplyAsync(() -> query("A"));\nCompletableFuture<String> f2 = supplyAsync(() -> query("B"));\n\nString result = f1.thenCombine(f2, (a, b) -> a + b)\n                     .thenApply(String::toUpperCase)\n                     .get(5, TimeUnit.SECONDS);', 'thenCombine 用于两个独立任务的合并。', 1),
(39, 'java', 'KingBase JDBC 连接', '// 驱动: cn.com.kingbase:kingbase8\n// 类名: com.kingbase8.Driver\nString url = "jdbc:kingbase8://localhost:54321/javacourse"\n             + "?currentSchema=public&characterEncoding=UTF-8";\n\ntry (Connection conn = DriverManager.getConnection(url, "app", "pwd")) {\n    PreparedStatement ps = conn.prepareStatement(\n        "SELECT id, title FROM lesson WHERE module_id = ?");\n    ps.setLong(1, 1L);\n    try (ResultSet rs = ps.executeQuery()) {\n        while (rs.next()) {\n            System.out.println(rs.getString("title"));\n        }\n    }\n}', '参数绑定防 SQL 注入，是强制要求。', 1);

INSERT INTO knowledge_point (name, category, description) VALUES
('基本类型', '语言基础', '8 种基本类型与引用类型'),
('运算符', '语言基础', '算术、比较、逻辑与位运算'),
('流程控制', '语言基础', '分支、循环与跳转'),
('字符串', '语言基础', 'String、StringBuilder 与常量池'),
('封装', '面向对象', '访问控制与内部状态保护'),
('继承', '面向对象', '代码复用与方法重写'),
('多态', '面向对象', '运行时绑定与向上转型'),
('接口', '面向对象', '抽象契约与默认方法'),
('泛型', '面向对象', '类型参数与类型擦除'),
('异常', '面向对象', '受检与非受检异常'),
('反射', '面向对象', '运行时元编程'),
('注解', '面向对象', '元数据标记'),
('集合框架', '集合', 'List/Set/Map 体系'),
('迭代器', '集合', 'fail-fast 与并发修改'),
('Stream', '集合', '声明式数据处理与并行流'),
('内存模型', 'JVM', '堆栈方法区与 GC Roots'),
('类加载', 'JVM', '双亲委派与初始化时机'),
('垃圾回收', 'JVM', 'GC 算法与调优'),
('字节码', 'JVM', 'class 文件结构与指令'),
('线程', '并发', '生命周期与中断机制'),
('锁', '并发', 'synchronized 与 AQS'),
('线程池', '并发', '参数配置与拒绝策略'),
('原子类', '并发', 'CAS 与 ABA'),
('异步编排', '并发', 'CompletableFuture 组合'),
('Spring Boot', '框架', '自动装配与 starter'),
('RESTful', '框架', '资源建模与状态码'),
('KingBase', '框架', '国产数据库接入实践');

INSERT INTO lesson_knowledge (lesson_id, kp_id)
SELECT l.id, k.id FROM lesson l JOIN knowledge_point k ON
 (l.title LIKE '%类型%' AND k.name = '基本类型') OR
 (l.title LIKE '%运算符%' AND k.name = '运算符') OR
 (l.title LIKE '%流程控制%' AND k.name = '流程控制') OR
 (l.title LIKE '%字符串%' AND k.name = '字符串') OR
 (l.title LIKE '%封装%' OR l.title LIKE '%继承%' OR l.title LIKE '%多态%') AND k.category = '面向对象' OR
 (l.title LIKE '%接口%' AND k.name = '接口') OR
 (l.title LIKE '%泛型%' AND k.name = '泛型') OR
 (l.title LIKE '%异常%' AND k.name = '异常') OR
 (l.title LIKE '%反射%' AND k.name = '反射') OR
 (l.title LIKE '%注解%' AND k.name = '注解') OR
 (l.title LIKE '%集合%' OR l.title LIKE '%HashMap%' OR l.title LIKE '%ArrayList%' OR l.title LIKE '%Set%') AND k.category = '集合' OR
 (l.title LIKE '%迭代器%' AND k.name = '迭代器') OR
 (l.title LIKE '%Stream%' AND k.name = 'Stream') OR
 (l.title LIKE '%JVM%' OR l.title LIKE '%内存%' OR l.title LIKE '%类加载%' OR l.title LIKE '%垃圾回收%' OR l.title LIKE '%字节码%') AND k.category = 'JVM' OR
 (l.title LIKE '%线程%' AND k.name = '线程') OR
 (l.title LIKE '%锁%' AND k.name = '锁') OR
 (l.title LIKE '%线程池%' AND k.name = '线程池') OR
 (l.title LIKE '%CompletableFuture%' AND k.name = '异步编排') OR
 (l.title LIKE '%Spring Boot%' AND k.name = 'Spring Boot') OR
 (l.title LIKE '%RESTful%' AND k.name = 'RESTful') OR
 (l.title LIKE '%KingBase%' AND k.name = 'KingBase');

INSERT INTO search_index (target_type, target_id, title, body_text, tokens, ref_url)
SELECT 'LESSON', id, title, COALESCE(summary,'') || ' ' || COALESCE(content,''),
       title || ' ' || COALESCE(summary,''), '/lesson/' || slug FROM lesson;

INSERT INTO search_index (target_type, target_id, title, body_text, tokens, ref_url)
SELECT 'MODULE', id, title, COALESCE(summary,''), title || ' ' || COALESCE(summary,''),
       '/course/java-mastery#module-' || id FROM course_module;

