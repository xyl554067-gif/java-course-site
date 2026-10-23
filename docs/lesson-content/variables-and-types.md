## 本节要点

Java 有 8 种基本类型和 4 种引用类型。基本类型有固定的内存宽度与取值范围；包装类型则是对象，有缓存、有方法、能为 null。基本类型与包装类型之间的转换叫**装箱/拆箱**，自动装箱有缓存机制与性能代价。

## 核心概念

- **8 种基本类型**：`byte`(1) `short`(2) `int`(4) `long`(8) `float`(4) `double`(8) `char`(2) `boolean`(1)。
- **整数范围**：byte −128~127，short −32768~32767，int 约 ±21 亿，long 约 ±922 亿亿。
- **浮点精度**：float 约 7 位有效数字，double 约 15–16 位。**0.1 + 0.2 != 0.3**。
- **字符编码**：char 是 UTF-16 code unit，**一个 char 存不下一个 emoji**（需两个 char）。
- **包装类型**：Byte、Short、Integer、Long、Float、Double、Character、Boolean。
- **自动装箱**：编译器在需要对象的地方自动 `valueOf`；自动拆箱自动调用 `xxxValue()`。
- **Integer 缓存**：−128~127 缓存，范围外每次 new（`new Integer` 已废弃）。
- **类型提升**：小类型参与运算自动提升为大类型（byte+byte → int）。
- **强制类型转换**：大转小需显式，会截断（不是四舍五入）。
- **常量池与编译期常量**：`final` 修饰的基本类型/String 编译期常量会被内联。
- **整数常量后缀**：`L`/`l`（long）、`0x`（十六进制）、`0b`（二进制）、`_`（分隔符）。

## 关键代码

```java
// 自动装箱与缓存
Integer a = 127, b = 127;
System.out.println(a == b);          // true —— 缓存内
Integer c = 128, d = 128;
System.out.println(c == d);          // false —— 超出缓存，各自 new
Integer e = 128;
Integer f = new Integer(128);        // 已废弃，但仍绕过缓存
System.out.println(e.equals(f));     // true —— equals 比值

// 拆箱 NPE：包装类型可能为 null
Integer maybeNull = null;
int value = maybeNull;               // NullPointerException！

// 类型提升
byte b1 = 10, b2 = 20;
int sum = b1 + b2;                   // byte 相加先提升为 int
// byte bad = b1 + b2;               // 编译错误：需要显式强转

// 浮点精度
System.out.println(0.1 + 0.2);       // 0.30000000000000004
System.out.println(0.1 + 0.2 == 0.3);// false

// 精度处理
BigDecimal money = new BigDecimal("0.1").add(new BigDecimal("0.2"));
System.out.println(money);           // 0.3 —— 必须用字符串构造！

// 整数常量
long big = 1_000_000_000L;
int hex = 0xFF;
int bin = 0b1010;
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 `Integer == Integer` 比较值——引用比较，需用 equals
- 以为 `new Integer(128)` 与 `Integer.valueOf(128)` 相等——前者不走缓存
- 用 `double` 处理金额——精度问题，应使用 `BigDecimal`
- 用 `new BigDecimal(0.1)`——会带入二进制误差，必须用字符串构造
- 忘记自动拆箱可能 NPE
- 认为 char 能存中文和 emoji——char 只有 16 位，中文 BMP 内可以，emoji 不行

## 动手练习

写一个程序验证 Integer 缓存边界、`0.1 + 0.2` 的精度问题，以及 char 与 emoji 的存储差异。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭 Java 基础篇》《面渣逆袭Java基础篇V2.0（暗黑）》《面试题-01-Java基础知识面试题》《二哥修订版《30天速通Java》暗黑版》《Java编程思想第四版》对本节有完整覆盖。

**基本类型与包装类型的对应**

《面试题-01-Java基础知识面试题》的「基础语法 → 数据类型」部分给出了完整对照，并强调 Java 早期版本包装类型是为「一切皆对象」的纯粹性做的妥协——实际上基本类型无法参与泛型、无法作为集合元素的高效存储。

**Integer 缓存的精确范围**

《面渣逆袭Java基础篇V2.0（暗黑）》与《面渣逆袭 Java 基础篇》都指出缓存范围是 **−128 到 127**，并说明其来源：`Integer.valueOf` 源码里有一个 `Integer[] cache` 静态数组在类加载时初始化。

关键结论：

```java
Integer i1 = 1, i2 = 1;
i1 == i2;              // true  —— 缓存
Integer i3 = new Integer(1);
i1 == i3;              // false —— new 绕过缓存
i1.equals(i3);         // true  —— equals 比值
```

书中还指出 `Integer.valueOf` 与 `new Integer` 的性能差异——前者能复用缓存对象，后者每次都分配新对象（且 `new Integer` 在 JDK 9 已 deprecated，JDK 16 移除）。

**自动装箱的性能代价**

《面渣逆袭 Java 基础篇》强调装箱不是免费的：

- 每个装箱都会 `new` 一个对象（除非命中缓存）
- 在循环里装箱会产生大量短命对象，增加 GC 压力
- 拆箱则调用 `intValue()`，有方法调用开销

```java
// 循环里用 int 累加，无装箱
int sum = 0;
for (int i = 0; i < 1000000; i++) sum += i;

// 循环里装箱，产生大量 Integer 对象
Integer sum = 0;    // 注意：这里每次 i++ 都会装箱
for (int i = 0; i < 1000000; i++) sum += i;
```

**浮点数精度问题**

《面渣逆袭 Java 基础篇》与《二哥修订版《30天速通Java》暗黑版》都解释了 `0.1 + 0.2 != 0.3` 的原因：

0.1 在二进制中是**无限循环小数**，double 用 52 位尾数只能近似存储。因此 `0.1` 的实际值略大于 1/10，`0.2` 略大于 2/10，两者相加后不等于 0.3 的实际值。

**BigDecimal 的正确用法**

书中特别强调构造方式：

```java
new BigDecimal(0.1);      // 错 —— double 的二进制误差被带入
new BigDecimal("0.1");    // 对 —— 从字符串精确解析
BigDecimal.valueOf(0.1);  // 对 —— 内部走 Double.toString
```

还提到 BigDecimal 的比较要用 `compareTo` 而非 `equals`——`equals` 会额外比较 scale（`1.0` 与 `1.00` 用 equals 不相等，用 compareTo 相等）。

**char 与 Unicode**

《面渣逆袭Java基础篇V2.0（暗黑）》指出：

- `char` 是 UTF-16 的**码元（code unit）**，16 位
- 基本多文种平面（BMP）内的字符（如常用汉字）用一个 char 够
- **emoji 等星外平面字符需要两个 char**（代理对 surrogate pair）

```java
char c = '中';              // OK，U+4E2D
String emoji = "😀";        // 长度是 2（两个 char）
System.out.println("😀".length());   // 2
```

**类型提升规则**

《面试题-01》给出了运算中的自动转换规则：

- 字节、短整型、字符型 → 整型（byte + byte → int）
- 整型 + 短整型 → 整型
- 短整型 + 整型 → 整型
- 整型 + 长整型 → 长整型
- 长整型 + 浮点型 → 浮点型

**注意所有运算都会向 double 靠拢的规则**：`float` 与 `double` 参与运算，结果必然是 `double`（除非显式指定）。

**字面量的八进制与十六进制陷阱**

《面渣逆袭 Java 基础篇》指出一个经典 bug：

```java
int a = 010;      // 八进制！= 8
int b = 0b10;     // 二进制 = 2
int c = 0x1F;     // 十六进制 = 31
```

八进制的 `010` 常被误以为是十进制 10。

**字符串常量池**

《二哥的 Java 进阶之路暗黑版》指出字符串常量池是**运行期**数据结构，位于堆中（JDK 7 起从永久代移到堆）。字面量 `"abc"` 会进池，`new String("abc")` 不会——这解释了 `==` 与 `equals` 的差异：

```java
String s1 = "abc";
String s2 = "abc";
String s3 = new String("abc");
s1 == s2;   // true  —— 同一个池中对象
s1 == s3;   // false —— 不同对象
s1.equals(s3);  // true
```

**编译期常量折叠**

《二哥的 Java 进阶之路》指出 `static final` 的基本类型/String 常量会在编译期直接内联到使用处：

```java
static final int MAX = 100;
int x = MAX;      // 编译后字节码里是 100，不是读 MAX 字段
```

因此修改 `MAX` 的值后，调用方需要重新编译才生效。

## 实战提示

**选型速查**：

| 场景 | 选择 |
| --- | --- |
| 金额计算 | `BigDecimal`（字符串构造） |
| 金额展示 | `BigDecimal.setScale(2, RoundingMode.HALF_UP)` |
| 计数/索引 | `int` / `long` |
| 需要 null 语义 | 包装类型 |
| 金额比较 | `compareTo` 而非 `equals` |
| 大量装箱场景 | 保持基本类型 |

**金额处理的完整示例**：

```java
BigDecimal price = new BigDecimal("19.90");
BigDecimal qty = new BigDecimal("3");
BigDecimal total = price.multiply(qty).setScale(2, RoundingMode.HALF_UP);
System.out.println(total);       // 59.70

// 相等判断
price.compareTo(new BigDecimal("19.9")) == 0;   // true
```

**自动拆箱 NPE 的防御**：

```java
// 危险：maybeNull 为 null 时直接 NPE
int v = maybeNull;

// 安全
int v = (maybeNull != null) ? maybeNull : 0;
```

**基本类型数组与包装类型数组的内存差异**：

```java
int[] intArr = new int[1000];        // 4KB
Integer[] boxArr = new Integer[1000]; // 约 4KB + 1000 个对象头（每个约 16B）≈ 20KB
```

大数组场景下这个差异很明显。

**equals 与 hashCode 的配套**（见面向对象课时）：包装类型的 equals 是值比较，hashCode 与值相关，因此可以安全地作为 HashMap 的 key。
