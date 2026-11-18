const i=[{id:"basics",label:"语言基础"},{id:"oop",label:"面向对象"},{id:"collections",label:"集合与 Stream"},{id:"concurrency",label:"并发"},{id:"jvm",label:"JVM 诊断"},{id:"backend",label:"Spring 与数据库"}],r={"jls-arrays":{title:"Java 语言规范 · 数组",publisher:"Oracle",kind:"语言规范",url:"https://docs.oracle.com/javase/specs/jls/se17/html/jls-10.html",topics:["basics"],description:"查阅数组长度、合法下标、初始化和越界异常的语言规则。"},"jls-access":{title:"Java 语言规范 §6.6 · 访问控制",publisher:"Oracle",kind:"语言规范",url:"https://docs.oracle.com/javase/specs/jls/se17/html/jls-6.html#jls-6.6",topics:["oop"],description:"核对 public、protected、包访问权限和 private 在不同位置的访问条件。"},"java-learn":{title:"Dev.java · Java 官方教程",publisher:"Dev.java",kind:"教程",url:"https://dev.java/learn/",topics:["basics","oop","collections","jvm"],description:"从第一个 Java 程序学起，也可按主题查阅泛型、集合、Stream 和 JVM 工具。"},"liaoxuefeng-java":{title:"廖雪峰 Java 教程",publisher:"廖雪峰",kind:"中文教程",url:"https://liaoxuefeng.com/books/java/index.html",topics:["basics","oop","collections","backend"],description:"从 Java 基础和面向对象入门，也可查阅集合、异常和 JDBC 的中文章节。"},"think-java":{title:"Think Java（第 2 版）",publisher:"Allen B. Downey、Chris Mayfield",kind:"英文教材 / PDF",url:"https://greenteapress.com/wp/think-java-2e/",topics:["basics","oop"],description:"可下载 PDF，适合配合数组、循环、类与方法的课时阅读。教材采用 CC BY-NC-SA 4.0 许可。"},"jdk-list":{title:"Java 17 API · List",publisher:"Oracle",kind:"API 文档",url:"https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/List.html",topics:["collections"],description:"查看 List 的顺序语义、List.of 与 List.copyOf 的行为及限制。"},"jdk-stream":{title:"Java 17 API · java.util.stream",publisher:"Oracle",kind:"API 文档",url:"https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/stream/package-summary.html",topics:["collections"],description:"理解数据源、中间操作、终止操作，以及流的惰性求值。"},"exercism-java":{title:"Exercism Java · 编程练习",publisher:"Exercism",kind:"在线题库",url:"https://exercism.org/tracks/java/exercises",topics:["basics","oop","collections"],description:"按概念挑选 Java 练习，用测试检验实现。适合学完一个主题后加练。"},"jdk-executor":{title:"Java 17 API · ExecutorService",publisher:"Oracle",kind:"API 文档",url:"https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/concurrent/ExecutorService.html",topics:["concurrency"],description:"查阅如何提交任务、接收 Future，以及有序关闭线程池。"},"jdk-future":{title:"Java 17 API · Future",publisher:"Oracle",kind:"API 文档",url:"https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/concurrent/Future.html",topics:["concurrency"],description:"核对 get 的等待、超时、取消和任务失败时的行为。"},"jdk-jcmd":{title:"JDK 17 工具手册 · jcmd",publisher:"Oracle",kind:"工具手册",url:"https://docs.oracle.com/en/java/javase/17/docs/specs/man/jcmd.html",topics:["jvm"],description:"查找 Java 进程、列出诊断命令，并读取堆的概况。"},"doocs-jvm":{title:"Doocs JVM · 虚拟机原理",publisher:"Doocs 技术社区",kind:"中文笔记",url:"https://github.com/doocs/jvm",topics:["jvm"],description:"查阅 JVM 内存结构、对象分配、类加载和垃圾回收的中文专题。"},"spring-rest":{title:"Spring Guides · 构建 REST 服务",publisher:"Spring",kind:"项目示例",url:"https://spring.io/guides/gs/rest-service/",topics:["backend"],description:"跟着可运行的案例学习请求映射、查询参数和 JSON 响应。"},"spring-jdbc":{title:"Spring Guides · 通过 JDBC 访问关系型数据",publisher:"Spring",kind:"项目示例",url:"https://spring.io/guides/gs/relational-data-access/",topics:["backend"],description:"通过完整示例学习 JdbcTemplate 的建表、写入和查询用法。"},"jdk-prepared-statement":{title:"Java 17 API · PreparedStatement",publisher:"Oracle",kind:"API 文档",url:"https://docs.oracle.com/en/java/javase/17/docs/api/java.sql/java/sql/PreparedStatement.html",topics:["backend"],description:"查询 SQL 占位符的绑定方式、从 1 开始的参数索引和执行方法。"},"kingbase-jdbc":{title:"KingbaseES V8 · JDBC 建立与关闭连接",publisher:"人大金仓",kind:"产品手册",url:"https://bbs.kingbase.com.cn/kingbase-html/v8/development/client-interfaces/jdbc/jdbc-2.html",topics:["backend"],description:"对应本站本地数据库，核对 JDBC URL、驱动和连接参数。"}},s=[{id:"array-boundaries",lessonSlug:"arrays",lessonTitle:"数组与一维二维遍历",topic:"basics",title:"用空数组检验下标边界",summary:"用长度为 0、1 和 3 的数组检验同一个遍历条件。",explanation:["长度为 n 的数组中，合法下标从 0 到 n - 1。空数组的长度是 0，因此它没有可读取的下标。","从 0 开始遍历时，用 i < values.length 作为条件。这样空数组不会进入循环，非空数组也会在读完最后一个元素后停止。"],example:{setup:"在 JDK 17 的 JShell 中依次输入以下代码。",code:`int sum(int[] values) {
    int total = 0;
    for (int i = 0; i < values.length; i++) {
        total += values[i];
    }
    return total;
}
System.out.println(sum(new int[] {}));
System.out.println(sum(new int[] {7}));
System.out.println(sum(new int[] {3, 5, 7}));`,result:"依次输出 0、7、15。"},exercise:{question:"把循环条件改为 i <= values.length 后，空数组和单元素数组分别在哪个下标出错？",answer:"空数组第一次尝试读取下标 0 就会越界。单元素数组先读取下标 0，下一轮读取下标 1 时越界。"},sources:["jls-arrays","think-java"]},{id:"encapsulation-rules",lessonSlug:"oop-core",lessonTitle:"封装、继承与多态",topic:"oop",title:"用封装守住余额规则",summary:"用 private 字段和一个提现方法，观察失败操作如何保留原有余额。",explanation:["把余额字段设为 private 后，普通调用者通过账户提供的方法读取或调整余额。方法集中检查金额，调用者无需分别实现同一套校验。","这个示例的规则是余额始终非负。提现方法先拒绝非正金额和超出余额的金额，再执行扣减。失败分支在修改之前返回。"],example:{setup:"在 JShell 中定义一个简化的积分账户。",code:`class Account {
    private int balance = 100;

    int balance() {
        return balance;
    }

    boolean withdraw(int amount) {
        if (amount <= 0 || amount > balance) {
            return false;
        }
        balance -= amount;
        return true;
    }
}
Account account = new Account();
System.out.println(account.withdraw(30));
System.out.println(account.withdraw(80));
System.out.println(account.balance());`,result:"依次输出 true、false、70。"},exercise:{question:"余额为 70 时，提现 70 和提现 -10 会怎样？",answer:"提现 70 成功，余额变为 0。提现 -10 会被拒绝，余额保持操作前的值。"},sources:["jls-access","java-learn","liaoxuefeng-java"]},{id:"list-snapshots",lessonSlug:"collection-overview",lessonTitle:"Collection 体系全景图",topic:"collections",title:"保存列表快照",summary:"用 List.copyOf 保存一份名单，并验证原列表追加元素后的结果。",explanation:["如果要把待提交名单交给另一个方法，可以用 List.copyOf 保存当前元素及其顺序。后续增删原列表的元素时，快照的结构仍保持创建时的样子。","List.copyOf 会拒绝 null 元素。快照中的元素仍可能是可变对象，所以需要逐个复制对象时，要在业务代码中明确复制规则。"],example:{setup:"在 JShell 中运行下面的名单示例。",code:`import java.util.ArrayList;
import java.util.List;

var draft = new ArrayList<>(List.of("小林", "小余"));
var submitted = List.copyOf(draft);
draft.add("小周");
System.out.println(draft);
System.out.println(submitted);`,result:"原名单输出 [小林, 小余, 小周]，快照输出 [小林, 小余]。"},exercise:{question:"如果接收方也要增删名单，如何创建一份独立的可修改列表？",answer:"用 new ArrayList<>(draft) 创建可修改的列表。两份列表的结构可以独立修改，可变元素对象仍可能由两份列表共享。"},sources:["jdk-list","exercism-java"]},{id:"stream-results",lessonSlug:"stream-api",lessonTitle:"Stream API 与函数式编程",topic:"collections",title:"用 Stream 计算及格平均分",summary:"把筛选、类型转换和求平均拆成三个步骤，并处理没有及格成绩的输入。",explanation:["先用 filter 留下不低于 60 的分数，再用 mapToInt 得到整数流。最后的 average 触发流水线求值，并返回 OptionalDouble。","所有成绩都低于 60 时，结果为空。页面可以据此显示「无及格成绩」，避免把没有样本和实际数值混在一起。"],example:{setup:"在 JShell 中运行，然后把每个分数都改为低于 60。",code:`import java.util.List;
import java.util.OptionalDouble;

OptionalDouble passingAverage(List<Integer> scores) {
    return scores.stream()
        .filter(score -> score >= 60)
        .mapToInt(Integer::intValue)
        .average();
}

var scores = List.of(85, 58, 75);
var average = passingAverage(scores);
System.out.println(average.isPresent() ? String.valueOf(average.getAsDouble()) : "无及格成绩");`,result:"第一次输出 80.0。全部改为不及格分数时，输出「无及格成绩」。"},exercise:{question:"要统计及格人数，保留 filter 后还需要哪些操作？",answer:"在 filter 后调用 count() 即可，返回人数的类型是 long。因为只统计元素个数，可以省略 mapToInt。"},sources:["jdk-stream","java-learn"]},{id:"future-results",lessonSlug:"thread-pool",lessonTitle:"线程池的原理与调优",topic:"concurrency",title:"用 Future 接收任务结果",summary:"提交一个带返回值的任务，设置等待上限，并读懂线程池关闭的时机。",explanation:["ExecutorService.submit 返回 Future，可在需要结果时调用 get。调用带超时参数的 get，可以限制调用方等待的时间。","等待超时后，任务仍可能继续执行。需要取消时应显式调用 cancel，并让任务配合中断。示例在 finally 中调用 shutdown，让线程池完成已提交的任务并停止接收新任务。"],example:{setup:"在 JShell 中输入下面的代码，比较 submit 和 get 各自负责的工作。",code:`import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

var pool = Executors.newSingleThreadExecutor();
try {
    var result = pool.submit(() -> 6 * 7);
    System.out.println(result.get(2, TimeUnit.SECONDS));
} finally {
    pool.shutdown();
}`,result:"任务在两秒内完成时输出 42。"},exercise:{question:"如果任务执行时抛出异常，get 会把失败当成一个正常返回的值吗？",answer:"get 会抛出 ExecutionException，可以用 getCause() 查看任务抛出的异常。"},sources:["jdk-executor","jdk-future"]},{id:"jvm-heap-observation",lessonSlug:"jvm-tuning-tools",lessonTitle:"JVM 调优实战与工具链",topic:"jvm",title:"用 jcmd 观察堆使用量",summary:"先找到本机 Java 进程，再采集两次堆快照信息进行比较。",explanation:["在运行测试程序的同一台电脑上，用同一账号运行 jcmd -l，找到目标 Java 进程的 PID。随后用 help 查看该进程支持的诊断命令。","GC.heap_info 展示采样时的堆信息，可先记下基线，再在同一操作重复若干次后对照。单次增长可能只是本轮分配尚未回收，需要结合多次采样和应用行为判断。"],example:{setup:"在终端运行，先启动自己的 Java 测试程序，并把 12345 换成该程序的 PID。",code:`jcmd -l
jcmd 12345 help
jcmd 12345 GC.heap_info`,result:"第一条列出进程，第二条列出目标支持的命令，第三条打印堆概况。字段随垃圾收集器而异。"},exercise:{question:"两次采样显示堆使用量增加，下一步应该如何验证？",answer:"在相近负载和相同采样条件下多测几次，观察垃圾回收后的用量是否持续上升，再检查相关对象是否一直被引用。"},sources:["jdk-jcmd","doocs-jvm"]},{id:"rest-query-parameters",lessonSlug:"restful-api",lessonTitle:"RESTful API 设计规范",topic:"backend",title:"把请求参数变成 JSON 响应",summary:"写一个返回课时预览的 GET 接口，验证有无查询参数时的行为。",explanation:["@GetMapping 将 GET 请求映射到方法，@RequestParam 读取 URL 查询参数并可提供默认值。浏览器可以通过 ?topic=arrays 指定主题。","在配置了 JSON 消息转换器的 Spring Boot Web 应用里，@RestController 方法返回的记录对象由 Spring 序列化为 JSON。这个示例的处理过程仅生成响应。"],example:{setup:"在带有 Spring Web 的 Spring Boot 示例项目中，将控制器放进应用组件扫描的包。",code:`import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
class LessonPreviewController {
    record LessonPreview(String topic, String status) {}

    @GetMapping("/api/lesson-preview")
    LessonPreview preview(@RequestParam(name = "topic", defaultValue = "hello-world") String topic) {
        return new LessonPreview(topic, "ready");
    }
}`,result:"GET /api/lesson-preview?topic=arrays 返回包含 topic 为 arrays、status 为 ready 的 JSON。"},exercise:{question:"直接请求 /api/lesson-preview 时，topic 字段是什么？",answer:"topic 为 hello-world，因为请求没有提供该查询参数，Spring 使用注解里的默认值。"},sources:["spring-rest"]},{id:"jdbc-bind-values",lessonSlug:"kingbase-persistence",lessonTitle:"用 KingBase 持久化数据",topic:"backend",title:"用 JDBC 参数查找课时",summary:"按课时 slug 查询标题，分别验证有匹配记录和没有匹配记录的情况。",explanation:["SQL 模板保留问号占位符，Java 用 setString 传入课时 slug。参数位置从 1 开始，executeQuery 后需要先调用 next 才能读取第一行。","示例用 try-with-resources 关闭查询产生的语句和结果集。Connection 由调用方提供，由调用方或框架负责管理其生命周期。"],example:{setup:"把方法放在持久化类中，传入已连接项目数据库的 Connection。",code:`import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

static List<String> findLessonTitles(Connection connection, String slug) throws SQLException {
    String sql = "SELECT title FROM lesson WHERE slug = ? ORDER BY id";
    var titles = new ArrayList<String>();
    try (var statement = connection.prepareStatement(sql)) {
        statement.setString(1, slug);
        try (var rows = statement.executeQuery()) {
            while (rows.next()) {
                titles.add(rows.getString("title"));
            }
        }
    }
    return titles;
}`,result:"有匹配记录时返回课时标题列表，无匹配记录时返回空列表。"},exercise:{question:"如果 WHERE 条件增加一个模块 ID 占位符，如何设置第二个参数？",answer:"在执行查询前调用 statement.setLong(2, moduleId)。参数序号按 SQL 中问号出现的顺序排列。"},sources:["jdk-prepared-statement","kingbase-jdbc","spring-jdbc"]}],n=Object.entries(r);function l(e){return s.find(t=>t.id===e)}function o(e){return"resource-"+e}function c(e){return s.find(t=>o(t.id)===e)}function u(e){var t;return((t=i.find(({id:a})=>a===e))==null?void 0:t.label)??e}export{u as a,o as b,i as c,r as d,l as e,n as f,c as g,s as r};
