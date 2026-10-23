## 本节要点

控制流分三类：**分支**（if/switch）、**循环**（for/while/do-while）、**跳转**（break/continue/return）。JDK 14+ 的 switch 表达式与 JDK 17 的模式匹配大幅增强了 switch 的能力，JDK 21 引入 `forEach` 与 `takeWhile`。

## 核心概念

- **if-else**：条件分支，遵循「先特殊后一般」或「先一般后特殊」的原则。
- **switch**：只能用于 int/short/byte/char/enum/String（JDK 7+）/ 引用类型（JDK 14+ 模式匹配）。
- **case 穿透（fall-through）**：不写 break 会继续执行下一个 case。
- **switch 表达式**（JDK 14+）：用 `->` 语法，必须**穷尽**（有返回值时），可多个标签 `case A, B ->`。
- **yield**（JDK 13+）：在 switch 表达式块中返回值。
- **模式匹配**（JDK 16+）：`if (o instanceof String s)` 直接绑定变量。
- **switch 模式匹配**（JDK 21）：`case String s -> ...`，配合 sealed 可做穷尽性检查。
- **for / for-each / while / do-while**：四种循环，do-while 至少执行一次。
- **增强 for**：编译为 Iterator 循环，遍历中删除会抛 CME。
- **break / continue / 标签（label）**：`break label` 可跳出多层循环。
- **条件的三元运算符**：`cond ? a : b`，只求值一个分支。
- **循环的提前退出**：break 跳出、return 退出方法、continue 跳过本次。
- **do-while 的典型用途**：至少执行一次的场景（菜单循环、输入校验）。

## 关键代码

```java
// if-else：先特殊后一般
if (score >= 90) {
    grade = "A";
} else if (score >= 60) {
    grade = "B";
} else {
    grade = "C";
}

// switch 表达式（JDK 14+）：穷尽、无需 break、返回值
int days = switch (month) {
    case 1, 3, 5, 7, 8, 10, 12 -> 31;
    case 4, 6, 9, 11 -> 30;
    case 2 -> isLeap(year) ? 29 : 28;
    default -> throw new IllegalArgumentException("非法月份");
};

// 模式匹配（JDK 16+）
if (obj instanceof String s && s.length() > 5) {
    System.out.println(s.toUpperCase());     // s 在此作用域可用
}

// switch 模式匹配（JDK 21）
String describe(Object o) {
    return switch (o) {
        case Integer i when i > 100 -> "大整数";
        case Integer i -> "整数 " + i;
        case String s -> "字符串 " + s;
        case null -> "null";
        default -> "其它";
    };
}

// 四种循环
for (int i = 0; i < 10; i++) { }             // 次数已知
for (String s : list) { }                    // 遍历集合
while (hasMore()) { }                        // 次数未知
do { process(); } while (hasMore());         // 至少执行一次

// break / continue
for (int i = 0; i < 10; i++) {
    if (i == 3) continue;    // 跳过本次
    if (i == 7) break;       // 跳出循环
}

// 标签：跳出多层循环
outer:
for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
        if (matrix[i][j] < 0) break outer;   // 直接跳出外层
    }
}

// do-while 的典型用法：输入校验
int value;
do {
    value = readInt("请输入 1-100 的数字：");
} while (value < 1 || value > 100);

// while + takeWhile（JDK 9+）：找到第一个不满足就停
Iterator<String> it = list.iterator();
it.forEachRemaining(System.out::println);
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- switch 忘记写 break 导致意外穿透
- 用 `==` 比较 String（switch 里是 `equals` 语义，但 if 里用 `==` 就错了）
- 在增强 for 中修改集合——抛 CME
- 认为 `if` 和 `switch` 可以随意互换——switch 要求类型有限且离散
- for-each 遍历时调用 `iterator().remove()` 之外的删除方式

## 动手练习

用 switch 表达式实现一个"计算器"，用标签循环在二维数组中查找第一个负数并输出其坐标。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭 Java 基础篇》《二哥修订版《30天速通Java》暗黑版》《面试题-01-Java基础知识面试题》《二哥的 Java 进阶之路暗黑版》对本节有覆盖。

**switch 表达式相比传统 switch 的改进**

《二哥修订版《30天速通Java》暗黑版》指出 switch 表达式（JDK 14+）解决了传统 switch 的三个痛点：

| 问题 | 传统 switch | switch 表达式 |
| --- | --- | --- |
| 漏写 break | 意外穿透 | **不可能穿透**（箭头语法） |
| 忘记返回值 | 编译错误 | 编译器强制**穷尽性检查** |
| 多个标签 | 重复写 case | `case A, B ->` |

**穷尽性检查**是最大的价值：传统 switch 漏掉一个分支会静默返回错误结果，而 switch 表达式在类型不穷尽时**编译不过**。

**模式匹配的演进**

《二哥的 Java 进阶之路暗黑版》与《二哥修订版《30天速通Java》暗黑版》梳理了 Java 模式匹配的三个阶段：

```java
// Java 16 之前：必须强转 + 先判空
if (obj instanceof String) {
    String s = (String) obj;
    System.out.println(s.length());
}

// Java 16+：instanceof 直接绑定变量
if (obj instanceof String s) {
    System.out.println(s.length());   // 作用域自动限定
}

// Java 21：switch 模式匹配
switch (obj) {
    case String s -> System.out.println(s.length());
    case Integer i -> System.out.println(i * 2);
    default -> System.out.println("其它");
}
```

**《面试题-01-Java基础知识面试题》的高频 switch 问题**

同一份资料把 switch 的考点集中在：

- `switch` 能否作用于 `byte`？**能**（会自动提升为 int）
- 能否作用于 `long`？**不能**（只有 int/short/byte/char 可以）
- 能否作用于 `String`？**能**（JDK 7+，用 equals 语义，不是 `==`）
- switch 表达式是否必须穷尽？**是**（否则编译错误）

**标签（label）的用法**

《面渣逆袭 Java 基础篇》与《二哥修订版《30天速通Java》暗黑版》都给出了标签的规范用法：

```java
search:
for (int i = 0; i < n; i++) {
    for (int j = 0; j < m; j++) {
        if (a[i][j] == target) {
            // 记录结果后跳出双层循环
            found = true;
            break search;
        }
    }
}
```

**注意**：label 必须紧跟在语句前（不能是变量声明），且 `break label` 只能跳出它所标注的那一层循环。

**do-while 的适用场景**

《二哥修订版《30天速通Java》暗黑版》指出 do-while 的核心价值是「**保证至少执行一次**」：

```java
// 典型：菜单循环
String choice;
do {
    showMenu();
    choice = readLine();
    handle(choice);
} while (!"q".equalsIgnoreCase(choice));

// 典型：输入校验
int age;
do {
    age = readInt();
} while (age < 0 || age > 150);
```

**增强 for 的实现与陷阱**

《面渣逆袭 Java 基础篇》指出增强 for 的限制：

```java
// 编译为
Iterator<String> it = list.iterator();
while (it.hasNext()) {
    String s = it.next();
    // ...
}
```

因此：

- 不能在增强 for 中修改集合结构（会 CME）
- 不能在增强 for 中调用 `iterator.remove()` 之外的方式删除
- 需要删除时用 `removeIf` 或显式迭代器

**《Effective Java》第 47 条：不要用异常控制流程**

书中以「switch 转 switch」为例说明——把一个 switch 重写成另一个 switch 只是为了「统一代码风格」，这类改动没有价值且引入风险。

**《Effective Java》第 68 条与循环中的 break**

书中提到一个性能细节：在循环中用 `break` 跳出比用条件判断 `return` 更快，因为 `break` 能让 JIT 更容易做循环优化。但这个差异通常不值得为此改变代码结构。

## 实战提示

**switch 的现代写法推荐**：

```java
// 推荐：switch 表达式 + 箭头语法 + 穷尽检查
return switch (status) {
    case CREATED -> "已创建";
    case PAID, SHIPPED -> "已支付";     // 多标签
    case CANCELLED -> "已取消";
    default -> "未知";
};
```

**什么时候用 switch，什么时候用 if**：

| 条件类型 | 选择 |
| --- | --- |
| 枚举 / 整型常量 / 字符串的有限取值 | switch |
| 区间判断、复杂布尔组合 | if-else |
| 类型判断 | switch 模式匹配（Java 21+） |

**循环中避免修改集合**：

```java
// 错误：ConcurrentModificationException
for (Order o : orders) {
    if (o.isExpired()) orders.remove(o);
}

// 正确
orders.removeIf(Order::isExpired);
```

**嵌套循环的性能提示**：内层循环能提前 break 就 break——用标签跳出多层，比用布尔标志清晰且更快：

```java
outer:
for (...) {
    for (...) {
        if (found) break outer;
    }
}
```

**可读性建议**：如果一个方法里出现了多个嵌套循环 + 多个 break + 布尔标志，通常说明该拆分成多个方法了。标签方案虽然更简洁，但深层嵌套（3 层以上）本身就提示需要重构。
