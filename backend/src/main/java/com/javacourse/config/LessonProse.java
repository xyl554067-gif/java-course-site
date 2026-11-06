package com.javacourse.config;

import java.util.regex.Pattern;

/** Removes editorial references from built-in Markdown while leaving fenced examples intact. */
final class LessonProse {
    private static final String BOOK = "《(?:[^《》\\r\\n]|《[^《》\\r\\n]*》)*》";
    private static final Pattern TITLES = Pattern.compile(BOOK);
    private static final Pattern BOOK_INTRO = Pattern.compile(
            "^(?:\\*\\*|[-*>]\\s+)?(?:知识库中的?|在知识库中)?" + BOOK
            + "(?:[^。！？；：—]{0,120}?" + BOOK + ")*[^。！？；：—]{0,120}?"
            + "(?:指出|强调|提醒|提到|建议|解释了?|讲清了?|梳理了?|区分了?|对比了?|列举了?|列出了?|介绍了?|给出(?:了|的)?|讨论了?|分析了?|推荐(?:使用)?|列为)"
            + "[：，,\\s]*");
    private static final Pattern REFERENCE_ONLY = Pattern.compile(
            "^(?:知识库(?:中的?|里)|本节的知识点在知识库中|本节可(?:对照|参考)|(?:参考|资料)来源[：:]|参考资料[：:]).*");
    private static final Pattern CITATION_DETAIL = Pattern.compile(
            "(?:第\\s*[\\d./、\\s]+\\s*[条章节](?:\\s*[/、]\\s*第\\s*[\\d.]+\\s*[条章节])?|原理篇|中文第二版|（在知识库中）)");
    private static final Pattern SOURCE_VERB = Pattern.compile(
            "(?:这本书|原书|该书|同一份资料|该资料|书中|这份资料)"
            + "(?:也|还|同时|明确|特别)*(?:指出|强调|提到|讲了?|讨论|建议|认为|给出(?:了|的)?|补充(?:了)?|提醒)[：，,\\s]*");
    private static final Pattern CITATION_ASIDE = Pattern.compile(
            "[（(](?:来自|见|依据|参考|知识库中)[^）)\\r\\n]*" + BOOK + "[^）)\\r\\n]*[）)]");

    private LessonProse() {}

    static String clean(String content) {
        StringBuilder result = new StringBuilder(content.length());
        boolean inCode = false;
        for (String line : content.split("(?<=\\n)", -1)) {
            String body = line.replaceFirst("\\r?\\n$", "");
            String ending = line.substring(body.length());
            if (body.stripLeading().startsWith("```")) {
                inCode = !inCode;
                result.append(line);
            } else if (inCode) {
                result.append(line);
            } else {
                String updated = cleanLine(body);
                if (updated != null) result.append(updated).append(ending);
            }
        }
        return result.toString();
    }

    private static String cleanLine(String line) {
        if (line.matches("^##\\s+延伸阅读[（(].*知识库.*[）)]\\s*$")) return "## 知识拓展";
        if (REFERENCE_ONLY.matcher(line).matches() && TITLES.matcher(line).find()) {
            // Opening source lists only describe which books cover the chapter.
            if (line.matches(".*(?:对本节|为本节|可对照|参考资料|参考来源).*")
                    && !line.matches(".*[。！？].+")) return null;
        }
        if (!TITLES.matcher(line).find()) return finishLine(line);

        String text = CITATION_ASIDE.matcher(line).replaceAll("");
        // Keep text before a citation and restart rewriting at the next sentence.
        StringBuilder result = new StringBuilder();
        for (String sentence : text.split("(?<=[。！？])", -1)) {
            if (TITLES.matcher(sentence).find()) result.append(cleanSentence(sentence));
            else result.append(sentence);
        }
        String cleaned = finishLine(result.toString().stripTrailing());
        return cleaned == null || cleaned.matches("^[\\s>*#：:，、。-]+$") ? null : cleaned;
    }

    private static String finishLine(String line) {
        String text = cleanSourcePhrases(line);
        if (text.equals(line) && line.isBlank()) return line;
        if (text.isBlank() || text.equals("」一节。")) return null;
        return text;
    }

    private static String cleanSentence(String sentence) {
        String text = sentence.stripLeading();
        String indent = sentence.substring(0, sentence.length() - text.length());
        if (text.matches("^(?:这条建议在|本节的知识点在|本节的内容在|知识库中的).*")) return "";
        if (text.startsWith("**《") && text.endsWith("**")) {
            String heading = stripTitles(text.substring(2, text.length() - 2));
            return heading.isEmpty() ? "" : indent + "### " + heading.replaceFirst("^与循环", "循环");
        }
        // Preserve labels and teaching text before the title, for example “**实践建议**：”.
        int firstTitle = text.indexOf('《');
        String before = text.substring(0, firstTitle);
        var intro = BOOK_INTRO.matcher(text);
        if (intro.find()) {
            String prefix = text.startsWith("**") ? "**"
                    : (text.startsWith("- ") || text.startsWith("> ") ? text.substring(0, 2) : "");
            text = prefix + stripTitles(text.substring(intro.end()));
        } else {
            var afterLabel = BOOK_INTRO.matcher(text.substring(firstTitle));
            text = before.stripTrailing().matches(".*[：:]$") && afterLabel.find()
                    ? before + stripTitles(text.substring(firstTitle + afterLabel.end()))
                    : stripTitles(text);
        }
        if (text.matches("^[，。；：:!！\\s]*$")) return "";
        return indent + text;
    }

    private static String stripTitles(String text) {
        String cleaned = TITLES.matcher(text).replaceAll("");
        cleaned = cleaned.replaceAll("(?:书中|原书|该书)(?:指出|强调|提到|建议)[：，,\\s]*", "");
        cleaned = cleaned.replaceAll("(?:（|\\()(?:依据|参考|见|来自)\\s*[）)]", "");
        cleaned = cleaned.replaceAll("^[\\s：:，、；]*(?:(?:以及|与|和|的|中|里|都|关于|而)\\s*)+", "");
        cleaned = CITATION_DETAIL.matcher(cleaned).replaceFirst("");
        return cleaned.replaceFirst("^[\\s：:，、；]+", "").stripTrailing();
    }

    private static String cleanSourcePhrases(String text) {
        text = text
                .replace("**Effective Java 第 3 条：永远不要覆盖 equals 和 hashCode**", "### equals 与 hashCode 的契约")
                .replace("共 57 条经验规则，专门讲这件事。核心结论：", "")
                .replace("- 唯一的例外是**不可变对象**——因为它的哈希码计算结果不会变",
                        "- 不可变对象同样遵循此契约：两个相等的对象必须返回相同的哈希码。")
                .replace("**Effective Java 第 17/18 条与接口优先原则**", "### 接口优先原则")
                .replace("**第 4 条与第 5 条的实用价值**：", "**控制对象的创建与复用**：")
                .replace("五条准则（前文已列），其中最实用的是与第 5 条：", "设计不可变对象时，先把握两个要点：")
                .replace("- 第 47 条：", "- ").replace("- 第 48 条：", "- ")
                .replace("标注「标记-整理算法（老年代）」，正是这个对应关系的出处。", "")
                .replace("本节的权威对照", "内存区域与垃圾回收的两个主题")
                .replace("把「JVM 内存区域概览」作为独立小节展开，可作为画图记忆的骨架；标题即「Java 内存区域与内存溢出异常」，第 3 章讲「垃圾收集」，两者构成内存区域与垃圾回收的两个主题。", "")
                .replaceAll("（Effective Java[^）]*）", "")
                .replaceFirst("^(\\*\\*)?(?:Effective Java\\s*)?第\\s*[\\d./\\s]+\\s*条(?:\\s*/\\s*第\\s*[\\d.]+\\s*条)?[：:]\\s*",
                        "$1");
        return SOURCE_VERB.matcher(text).replaceAll("")
                .replace("完整对照，并强调 Java 早期版本包装类型是为「一切皆对象」的纯粹性做的妥协——实际上", "")
                .replace("这本书把数组与「类型安全」作为核心议题，指出 ", "")
                .replace("这本书把 String 列为「不可变对象」的经典范例，并指出", "String 是不可变对象。")
                .replace("这本书把代理模式分为", "代理模式可分为")
                .replace("这本书把接口作为", "接口可以作为")
                .replace("这本书", "")
                .replace("原书讨论", "考虑")
                .replace("书中以", "以")
                .replace("书中给的", "")
                .replace("书中给出的", "")
                .replace("书中的建议是", "可以")
                .replace("书中明确反对——", "")
                .replaceAll("书中第\\s*\\d+\\s*条的结论很直接：", "")
                .replaceAll("书中第\\s*\\d+\\s*条列举了", "")
                .replaceAll("（Effective Java 第[^）]+）|（书中给出）", "")
                .replace("一灰灰 blog 在实战中指出：", "实战要点：")
                .replace("有一灰灰 blog 的实战技巧：", "实战技巧：")
                .replace("知识库中与覆盖了 Spring 的异常体系。核心注解：", "Spring 异常处理的核心注解：")
                .replace("本节要点参考了知识库中的与等资料，可对照以下知识点自查：", "可对照以下知识点自查：")
                .replace("知识库中列举的典型泄漏场景：", "典型泄漏场景：")
                .replace("知识库中与都覆盖了锁升级。要点：", "锁升级的要点：")
                .replace("知识库中", "")
                .replace("，并说明其来源：", "。实现上，")
                .replace("还提到 BigDecimal 的比较要用", "BigDecimal 的数值比较要用")
                .replace("文第二版专门讲了 `intern`：", "`intern()` 的行为：")
                .replace("文第二版（在知识库中）专门讲了 `intern`：", "`intern()` 的行为：")
                .replace("详细讲了常量池：", "字符串常量池：")
                .replace("这一点，很多教材说\"Java 是引用传递\"是**不准确的**。", "Java 的参数传递统一采用值传递。")
                .replace("整理了重写的约束：", "重写的约束：")
                .replace("| 场景 | |", "| 场景 | 设计建议 |")
                .replace("覆盖了 static 的几个要点：", "static 的几个要点：")
                .replace("record 时列出编译器自动生成的部分：", "record 自动生成的成员：")
                .replace("的精神在 record 上依然适用：record 组件若是可变对象，仍需防御性拷贝：", "record 组件若是可变对象，仍需考虑防御性拷贝：")
                .replace("覆盖了擦除的细节：", "类型擦除的几个细节：")
                .replace("把 PECS 讲得很清楚：", "PECS 的用法：")
                .replace("系统讲解了 Spring 的 IOC 实现原理，核心链路正是「注解 + 反射」：", "Spring IoC 的核心链路包含注解与反射：")
                .replace("**代理模式在中的位置**", "**代理模式的用途**")
                .replace("把 Java 集合分为三类：", "Java 集合的三种常见类型：")
                .replace("把 `putVal` 的逻辑拆得很清楚：", "`putVal` 的主要步骤：")
                .replace("「转换为红黑树链表转换为红黑树过程」：", "桶内链表转成红黑树的过程：")
                .replace("。并强调 **HashMap 的 key 应同时重写 hashCode 与 equals**", "。如果键类重写 `equals`，也要重写 `hashCode`")
                .replace("演示了 groupingBy 的三种形式：", "groupingBy 的三种形式：")
                .replace("「u2、u4、u8 分别代表……」的说明，这正是理解对象内存布局的另一半——", "")
                .replace("「u2、u4、u8 分别代表……」的说明，这是读懂 class 文件格式的必备前提：", "class 文件中无符号数的宽度：")
                .replace("「锁状态标志」与「转换为红黑树链表转换为红黑树过程」等运行时状态变化。", "")
                .replace("「G1 收集器常会被拿来与 CMS」做对比，两者的关键差异：", "G1 与 CMS 的关键差异：")
                .replace("**关于 Arthas**：的提到过它。", "**关于 Arthas**：")
                .replace("专门讲字节码指令，可归纳为 8 类：", "字节码指令可归纳为 8 类：")
                .replace("——与都提到自定义类加载器的生命周期管理。", "，尤其是自定义类加载器的生命周期管理。")
                .replace("覆盖了线程创建与生命周期管理、同步机制、JUC 工具、线程池配置优化、CompletableFuture 异步编程等 30 多个实战示例，其中线程池相关的实践正是泄漏高发区：", "线程池中的典型泄漏场景：")
                .replace("覆盖的工具正好构成本节的实操路径：", "常用的排查工具：")
                .replace("思维导图第 1.4 节专门讲「Java 线程与操作系统线程的关系」，同时覆盖了：", "Java 线程与操作系统线程的关系：")
                .replace("目录显示其\"基础篇\"讲线程组与线程优先级，第 4 章讲「Java 线程的状态及主要转化方法」，第 5 章讲线程间通信。它把线程状态分为 6 种：", "Java 将线程状态分为 6 种：")
                .replace("\"基础篇\"讲线程间通信。`Object.wait()` 的三个约束：", "线程间通信中，`Object.wait()` 有三个约束：")
                .replace("「锁、非公平锁底层采用 AQS 实现」。AQS 的核心结构：", "`ReentrantLock` 的公平锁和非公平锁都基于 AQS。AQS 的核心结构：")
                .replace("完整执行链路（与一致）：", "完整执行链路：")
                .replace("还覆盖了常用同步器，它们常常比 `synchronized` 更贴合场景：", "按场景选择同步器：")
                .replace("「转换为红黑树链表转换为红黑树过程」与「ConcurrentHashMap 扩容操作控制」。", "")
                .replace("系统讲解了 CAS（Compare And Swap）与 ABA 问题：", "CAS 与 ABA 问题：")
                .replace("覆盖了队列选型：", "队列选型：")
                .replace("专门讲「thenCompose() 方法」，这正是 CompletableFuture 家族最容易搞混的一组方法：", "CompletableFuture 的异步组合方法：")
                .replace("思维导图的基础篇是「操作系统线程调度」，其中 1.3 节「操作系统线程」覆盖了三种模型：", "操作系统线程的三种调度模型：")
                .replace("对 Spring 的 IOC 实现原理拆解得很细，与 Boot 的自动装配一脉相承：", "理解 Boot 自动配置可以从 Spring IoC 的装配流程入手：")
                .replace("补充了 Spring Boot 2.7 之后的关键变化：", "Spring Boot 2.7 引入了一项变化：")
                .replace("**推荐做法**（）：", "**推荐做法**：")
                .replace("补充了一个易踩的坑：", "常见误区：")
                .replace("详细讲解了 B+ 树索引的组织方式，KingbaseES", "B+ 树和 B-tree 都通过树结构组织索引。KingbaseES")
                .replace("用大量图示讲解了 InnoDB 与 PostgreSQL 在索引实现上的差异：", "InnoDB 与 PostgreSQL 的索引实现有一个区别：")
                .replace("系统讲解了多版本并发控制（MVCC），PostgreSQL/Kingbase 的实现思路类似：", "PostgreSQL 和 Kingbase 都通过 MVCC 实现并发控制：")
                .replace("性能排查第一手段。KingbaseES 中对应配置：", "慢查询日志可用于性能排查。KingbaseES 中对应配置：")
                .replace("### 的 RESTful 章节", "### RESTful 设计原则")
                .replace("因为它是分布式可靠性的基石：", "幂等性让分布式系统可以安全重试：")
                .replace("这张表：", "常见 HTTP 方法的语义：")
                .replace("开篇讲 CAP 定理（一致性 C、可用性 A、分区容错性 P，最多满足两个），这与 API 设计的关系是：", "CAP 定理讨论分区发生时一致性和可用性的取舍。对 API 设计而言，")
                .replace("消息队列的「幂等性」时也提到 HTTP 层的一致做法：", "消息队列和 HTTP 接口可采用类似的幂等处理：")
                .replace("本项目已在用 `@RestControllerAdvice` 做统一异常处理（见异常处理课时）。这与 REST 规范配合时的要点：", "本项目用 `@RestControllerAdvice` 统一处理 REST 接口的异常：");
    }
}
