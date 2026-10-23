## 本节要点

String 是**不可变类**——一旦创建内容不可变，这既是它的安全性来源，也是它性能问题的根源。字符串常量池、`intern()`、`StringBuilder` 与 `StringBuffer` 的取舍是本节核心。

## 核心概念

- **不可变性**：String 的字符数据存放在 `final byte[] value` 中，且不暴露引用。所有「修改」操作都返回新对象。
- **字符串常量池**：运行期数据结构，位于堆中。字面量会进池，`new String(...)` 不会。
- **intern()**：把字符串放进池并返回池中引用。
- **StringBuilder**：可变、可重复追加、**非线程安全**，单线程拼接首选。
- **StringBuffer**：可变、**线程安全**（方法级 synchronized），但有锁开销。
- **编译期拼接优化**：`"a" + "b"`（两个常量）编译期折叠成 `"ab"`；含变量时编译成 `StringBuilder`（或 JDK 9+ 的 `invokedynamic` + `StringConcatFactory`）。
- **final 修饰的 String**：常量池中的引用，编译期内联。
- **正则中的 String**：正则表达式本身建议用常量（避免重复编译）。
- **String 的 equals 与 hashCode**：都基于字符内容，因此可安全作为 HashMap 的 key。
- **String.split 的陷阱**：末尾空串会被丢弃；正则特殊字符需转义。
- **String.join / formatted**：Java 8+ / 15+ 的实用方法。
- **文本块**（Java 15+）：`"""` 包裹的多行字符串，适合写 SQL、JSON。

## 关键代码

```java
// 常量池与 intern
String s1 = "abc";
String s2 = "abc";
String s3 = new String("abc");
System.out.println(s1 == s2);          // true  —— 同一个池对象
System.out.println(s1 == s3);          // false —— new 绕过池
System.out.println(s1.equals(s3));     // true  —— 值比较
System.out.println(s3.intern() == s1); // true  —— intern 回到池

// 编译期常量折叠
String a = "he" + "llo";               // 编译期就是 "hello"
final String b = "hello";
String c = "hello";
System.out.println(a == b);            // true

// StringBuilder：单线程拼接
StringBuilder sb = new StringBuilder(64);
for (int i = 0; i < 1000; i++) sb.append(i).append(',');
String result = sb.toString();

// StringBuffer：多线程
StringBuffer buf = new StringBuffer();
buf.append("x");

// 字符串不可变性的实际影响
String s = "abc";
s = s.toUpperCase();      // 返回新对象，原 s 不变

// split 的坑
"a,b,,".split(",");                  // 长度 2，末尾空串被丢弃
"a,b,,".split(",", -1);              // 长度 4，保留所有
"a.b".split("\\.");                  // 点是正则元字符，必须转义

// join 与 formatted
String.join(", ", List.of("a", "b", "c"));
String.format("%s-%d", "id", 42);
"hello %s".formatted("world");       // Java 15+

// 文本块（Java 15+）
String sql = """
        SELECT id, title
        FROM lesson
        WHERE module_id = ?
        """;
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 用 `==` 比较字符串内容——必须用 equals
- 用 `new String("abc")` 初始化常量——白白创建对象且绕过池
- 认为 StringBuilder 是线程安全的——它不是
- 不知道 `split` 会丢弃末尾空串
- 在循环里用 `s = s + x` 拼接——每次都创建新对象，应该用 StringBuilder
- 把 String 当成可变缓冲区用

## 动手练习

写一个程序验证常量池行为、`split` 的边界差异，以及用 StringBuilder 与 `+=` 拼接 10 万次字符串的耗时差距。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Java编程思想第四版》《面渣逆袭 Java 基础篇》《二哥修订版《30天速通Java》暗黑版》《java实战演练35讲》《面试题-01-Java基础知识面试题》对本节有详细覆盖。

**《Java编程思想第四版》第 13 章：字符串**

这本书把 String 列为「不可变对象」的经典范例，并指出不可变性的三个好处：

1. **可以安全共享**：多个线程可以同时访问同一个 String
2. **可以安全缓存**：String 的 hashCode 被缓存
3. **线程安全**：没有可变状态，不需要同步

书中强调「不可变对象是安全的默认选择」——只有在性能确有必要时才考虑可变版本。

**字符串常量池的运行期机制**

《面渣逆袭 Java 基础篇》与《二哥的 Java 进阶之路暗黑版》都详细讲了常量池：

```java
String s1 = "hello";
String s2 = "hello";        // 编译期：两个引用指向池中同一个对象
String s3 = new String("hello");  // 运行期 new，不进池
String s4 = s3.intern();    // 运行期把 s3 的内容放进池，返回池引用
```

书中强调 JDK 7 起的**重要变化**：字符串常量池从**永久代移到了堆**中，理由是永久代空间有限且难以调优（`String` 数量多容易 OOM）。这带来一个好处——堆 dumps 时能直接看到字符串。

**字符串拼接的编译期优化**

《二哥修订版《30天速通Java》暗黑版》给出的结论：

| 写法 | 编译后 |
| --- | --- |
| `"a" + "b"` | 编译期折叠为 `"ab"`，无运行时开销 |
| `"a" + var` | 编译为 `StringBuilder`（或 JDK 9+ 的 `invokedynamic`） |
| `s + var + s2` | 编译为 `StringBuilder`，只创建一次 |
| `s += var` | 编译为 `new StringBuilder().append(s).append(var)` |

书中同时指出 **JDK 9+ 的 indy 字符串拼接优化**：JEP 280 用 `invokedynamic` + `StringConcatFactory` 替代了 `StringBuilder` 方案，生成的字节码更小、在 JIT 优化下能生成更高效的拼接代码。

**StringBuilder vs StringBuffer**

《Java编程思想第四版》给出的对比：

| | StringBuilder | StringBuffer |
| --- | --- | --- |
| 线程安全 | 否 | 是（方法级 synchronized） |
| 性能 | 更快 | 有锁开销 |
| 适用 | 单线程（几乎总是） | 确实需要多线程共享 |

书中明确指出：**几乎所有情况下都用 StringBuilder**，因为 StringBuffer 的同步开销只有在真正多线程共享同一个实例时才有意义，而这种场景本身就很罕见。

**《java实战演练35讲》的 String.format 性能陷阱**

一灰灰 blog 在实战中指出：

```java
// 循环里用 String.format —— 每次都解析格式串，很慢
for (int i = 0; i < 10000; i++) {
    String s = String.format("%s-%d", "id", i);
}

// 改进：预编译 Pattern（但只适用于正则）
```

同时它也给出了**不要过度优化**的提醒——绝大多数业务中字符串拼接的量级根本不构成瓶颈，StringBuilder 就足够了。

**正则表达式的编译**

《面试题-01-Java基础知识面试题》与《二哥修订版《30天速通Java》暗黑版》都提醒：

```java
// 每次调用都重新编译正则 —— 浪费
boolean matches = input.matches("\\d+");

// 改进：预编译 Pattern
private static final Pattern NUM = Pattern.compile("\\d+");
boolean matches = NUM.matcher(input).matches();
```

**split 的实现细节**

《面渣逆袭 Java 基础篇》指出 `String.split` 的两个坑：

```java
"a,b,,".split(",");        // → ["a", "b"]   末尾空串被丢弃
"a,b,,".split(",", -1);    // → ["a", "b", "", ""]  保留全部
",a".split(",");           // → ["", "a"]    前导空串保留
```

原因是 `split` 的实现先按正则切分，然后**移除末尾的空串**（除非 limit 为负数）。而 `limit = 0` 还有一个特殊含义——表示「不限制」，但仍会丢弃末尾空串。

**String 的其他实用方法**

《java实战演练35讲》与《二哥修订版《30天速通Java》暗黑版》列举了高频方法：

```java
s.isBlank();                   // Java 11+，只含空白字符
s.strip();                     // Java 11+，去首尾空白（比 trim 更全，trim 只去 <= ' '）
s.lines().count();             // Java 11+，按行流
s.repeat(3);                   // Java 11+
s.chars().forEach(c -> ...);   // 按 char
"a-b-c".chars().mapToObj(c -> String.valueOf(c)).collect(Collectors.joining());
String.valueOf(65);            // 转字符串
```

**字符串与字符数组**

《面渣逆袭 Java 基础篇》指出 `char` 与 `String` 的转换：

```java
char c = 'a';
String s1 = String.valueOf(c);        // 推荐
String s2 = c + "";                   // 能用但不优雅（c + "" 实际是 int + String）
String s3 = new String(new char[]{'a','b'});   // 从字符数组建字符串
char[] chars = s.toCharArray();
```

**《Effective Java》第 68 条：不要依赖 String 的 intern**

《Effective Java》中文第二版（在知识库中）专门讲了 `intern`：

- `intern` 的行为在 JDK 6 与 JDK 7 之间**发生过重大变化**
- JDK 6 中 intern 会把字符串副本放进永久代，需要复制内容；JDK 7 改为直接引用池中对象
- 不要依赖 `intern` 来做唯一性判断或性能优化
- 需要字符串池语义时用 `Set` 或 Guava 的 `Interner`

## 实战提示

**字符串拼接的实用规范**：

```java
// 单线程 —— StringBuilder
String join(List<String> parts) {
    return parts.stream().collect(Collectors.joining(", "));
}

// 循环累加 —— 一定要 StringBuilder
StringBuilder sb = new StringBuilder();
for (String p : parts) sb.append(p).append(',');

// 少量固定拼接 —— 直接 + 就行，编译器会优化
String key = prefix + id + suffix;
```

**正则的两种写法**：

```java
// 简单场景：直接用 String.matches
if (input.matches("\\d{6}")) { }

// 热点路径或复杂正则：预编译 Pattern
private static final Pattern PHONE = Pattern.compile("^1[3-9]\\d{9}$");
if (PHONE.matcher(input).matches()) { }
```

**内存优化**：`String.intern()` 不建议用于生产优化——它依赖 JDK 内部实现，且可能加剧常量池压力。真正需要「去重」的场景用 `HashSet` 显式管理。

**文本块的实用场景**（Java 15+，本项目 JDK 17 可用）：

```java
String json = """
        {
          "name": "%s",
          "age": %d
        }
        """.formatted(name, age);
```

比字符串拼接可读性好得多，也不会漏掉转义。
