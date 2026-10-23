-- ============================================================================
-- Java 课程介绍网站 — 课时正文增强内容（基于 ima「Java江湖」知识库校准）
-- ----------------------------------------------------------------------------
-- 说明：
--   本脚本只更新 lesson.content，不改动表结构与其他字段。
--   原始 seed.sql 保留初始内容，两者可叠加执行（后者覆盖正文）。
--
--   正文结构：
--     ## 本节要点 / ## 核心概念 / ## 关键代码 / ## 常见误区 /
--     ## 动手练习 / ## 延伸阅读（来自「Java江湖」知识库）
--   「延伸阅读」段落标注了每个知识点对应的知识库资料，便于溯源与后续更新。
--
--   字符说明：GBK 字符集不含少数字符（如 U+2212 −、U+2714 ✔、emoji），
--   已统一替换为语义等价的 ASCII/GBK 字符，保证在 oracle 兼容模式下也能完整落库。
--
-- 生成方式：scripts/export_content_seed.py（从运行中的库导出）
-- ============================================================================

BEGIN;


-- hello-world
UPDATE lesson SET content = '## 本节要点  认识 JDK、编译与运行，一分钟跑起你的第一个程序。    ## 核心概念  - JDK、JRE、JVM 三者的包含关系  - 源码到运行：javac 编译与 java 执行  - 为什么 Java 能跨平台    ## 关键代码  ```  public class HelloWorld {      public static void main(String[] args) {          System.out.println("Hello, Java!");      }  }  ```    > 注意：代码需 JDK 17 及以上，直接复制即可编译运行。    ## 常见误区  - [''以为 JDK、JRE、JVM 是三选一，实际上是层层包含'', ''编译和运行用的是不同命令：javac 编译，java 运行'']    ## 动手练习  新建一个目录，用记事本写 HelloWorld.java，用 javac 编译后用 java 运行，亲眼看到 .class 文件是怎么生成的。  ' WHERE slug = 'hello-world';

-- variables-and-types
UPDATE lesson SET content = '## 本节要点

Java 有 8 种基本类型和 4 种引用类型。基本类型有固定的内存宽度与取值范围；包装类型则是对象，有缓存、有方法、能为 null。基本类型与包装类型之间的转换叫**装箱/拆箱**，自动装箱有缓存机制与性能代价。

## 核心概念

- **8 种基本类型**：`byte`(1) `short`(2) `int`(4) `long`(8) `float`(4) `double`(8) `char`(2) `boolean`(1)。
- **整数范围**：byte -128~127，short -32768~32767，int 约 ±21 亿，long 约 ±922 亿亿。
- **浮点精度**：float 约 7 位有效数字，double 约 15–16 位。**0.1 + 0.2 != 0.3**。
- **字符编码**：char 是 UTF-16 code unit，**一个 char 存不下一个 emoji**（需两个 char）。
- **包装类型**：Byte、Short、Integer、Long、Float、Double、Character、Boolean。
- **自动装箱**：编译器在需要对象的地方自动 `valueOf`；自动拆箱自动调用 `xxxValue()`。
- **Integer 缓存**：-128~127 缓存，范围外每次 new（`new Integer` 已废弃）。
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

《面渣逆袭Java基础篇V2.0（暗黑）》与《面渣逆袭 Java 基础篇》都指出缓存范围是 **-128 到 127**，并说明其来源：`Integer.valueOf` 源码里有一个 `Integer[] cache` 静态数组在类加载时初始化。

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
char c = ''中'';              // OK，U+4E2D
String emoji = "";        // 长度是 2（两个 char）
System.out.println("".length());   // 2
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
' WHERE slug = 'variables-and-types';

-- operators
UPDATE lesson SET content = '## 本节要点

运算符分算术、关系、逻辑、位、赋值、其它六类。三个高频考点：**短路求值**（`&&`/`||`）、**运算符优先级**、**整数除法与取模**（除零抛异常、负数取模方向）。

## 核心概念

- **算术运算符**：`+ - * / % ++ --`。
- **整数除法**：两个整数相除结果取整（向零取整）。`5 / 2 == 2`，`-5 / 2 == -2`。
- **取模**：结果符号跟随**被除数**。`-5 % 2 == -1`。
- **除零**：整数除以 0 抛 `ArithmeticException`；浮点数除以 0 得 Infinity/NaN。
- **短路求值**：`&&` 左边为 false 时右边不执行；`||` 左边为 true 时右边不执行。
- **位运算符**：`& | ^ ~ << >> >>>`。
- **移位**：`<<` 左移（低位补 0，相当于 ×2）；`>>` 算术右移（补符号位）；`>>>` 逻辑右移（补 0）。
- **复合赋值**：`+= -= *= /= %= &= |= ^= <<= >>= >>>=` —— 左侧只求值一次。
- **运算符优先级**（高到低）：一元 → 乘除模 → 加减 → 移位 → 关系 → 相等 → 按位与/异或/或 → 逻辑与 → 逻辑或 → 三元 → 赋值。
- **类型提升**：二元算术运算前，操作数会被提升到共同类型。
- **短路是三目运算符的基础**：`cond ? a : b` 只求值一个分支。
- **浮点比较**：不要用 `==` 比较浮点数，应用 `Double.compare`。

## 关键代码

```java
// 整数除法与取模
int a = 5 / 2;        // 2  —— 向零取整
int b = -5 / 2;       // -2
int c = -5 % 2;       // -1 —— 符号跟随被除数
double d = 5.0 / 2;   // 2.5

// 除零
// int e = 1 / 0;    // ArithmeticException: / by zero
double f = 1.0 / 0;  // Infinity
double g = 0.0 / 0;  // NaN

// 短路求值：右边不执行
int[] arr = {1};
if (arr.length > 1 && arr[1] == 2) { }   // 安全，短路保护了越界访问

// 复合赋值：左侧只求值一次
int[] idx = {0};
int i = 0;
idx[i++] += 10;      // 等价于 idx[0] += 10，i 只自增一次 → i == 1

// 位运算
int n = 8;
n << 1;              // 16  —— 相当于 *2
n >> 2;              // 2
n >>> 2;             // 2
-8 >> 1;             // -4  —— 算术右移，补符号位
-8 >>> 1;            // 2147483644 —— 逻辑右移，补 0

// 用位运算判断奇偶与提取二进制位
(n & 1) == 0;        // 偶数
(n >> 3) & 1;       // 取第 3 位

// 三元运算符：只求值一个分支
String s = flag ? "yes" : "no";

// 浮点比较
Double.compare(0.1 + 0.2, 0.3) != 0;   // 正确
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 `5 / 2 == 2.5`——整数除法只取整
- 以为 `-5 % 2 == 1`——取模符号跟随被除数，结果是 -1
- 忽略短路求值，在 `&&` 右侧写可能抛异常的操作
- 误以为 `i++ + ++i` 有确定结果——Java 规定从左到右求值，但这样写毫无意义
- 用 `==` 比较浮点数
- 混淆 `>>` 与 `>>>`——负数上结果完全不同

## 动手练习

写一个程序验证短路求值的效果（右侧不执行），并用位运算实现「判断 2 的幂」与「反转整数的二进制位」。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭 Java 基础篇》《面渣逆袭Java基础篇V2.0（暗黑）》《面试题-01-Java基础知识面试题》《二哥修订版《30天速通Java》暗黑版》《java实战演练35讲》对本节有覆盖。

**运算符优先级表**

《面渣逆袭 Java 基础篇》给出了完整优先级（从高到低）：

| 优先级 | 运算符 | 结合性 |
| --- | --- | --- |
| 1 | `++` `--` `~` `!` | 右结合 |
| 2 | `*` `/` `%` | 左结合 |
| 3 | `+` `-` | 左结合 |
| 4 | `<<` `>>` `>>>` | 左结合 |
| 5 | `<` `>` `<=` `>=` `instanceof` | 左结合 |
| 6 | `==` `!=` | 左结合 |
| 7 | `&` | 左结合 |
| 8 | `^` | 左结合 |
| 9 | `\|` | 左结合 |
| 10 | `&&` | 左结合 |
| 11 | `\|\|` | 左结合 |
| 12 | `? :` | 右结合 |
| 13 | 赋值类 | 右结合 |

**实践建议**：不要依赖优先级，用括号显式表达意图。这条建议在《二哥修订版《30天速通Java》暗黑版》中被反复强调——「表达式中少用运算符优先级，多用括号」。

**短路求值的实用价值**

《面渣逆袭 Java 基础篇》指出短路最常见的用途是**安全访问**：

```java
// 先判空再访问，避免 NPE
if (obj != null && obj.getName().equals("x")) { }

// 或用 Optional
String name = Optional.ofNullable(obj).map(Object::getName).orElse("");
```

另一处应用是**性能**：

```java
// 前面的检查成本低且可能短路
if (list != null && !list.isEmpty() && list.get(0).equals("x")) { }
```

**整数除法与取模**

《面渣逆袭Java基础篇V2.0（暗黑）》给出的精确规则：

- 整数除法**向零取整**（不是向下取整）：`-7 / 2 == -3`
- 取模结果符号跟随**被除数**：`-7 % 2 == -1`
- 这两个规则组合起来，使得 `a % b` 的结果与 `a` 同号，且 `|a % b| < |b|`

《java实战演练35讲》里有一灰灰 blog 的实战技巧：

```java
// 取模的常见用途：判断闰年
boolean leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

// 正负转换（避开边界问题，比 Math.abs 更快）
int i = Integer.MIN_VALUE;
long abs = i < 0 ? -(long) i : i;   // 注意先转 long
```

**位运算的工程用途**

《二哥修订版《30天速通Java》暗黑版》与《java实战演练35讲》都列举了位运算的实际场景：

```java
// 1. 判断奇偶（比 % 2 更快）
boolean even = (n & 1) == 0;

// 2. 2 的幂判定
boolean isPowerOf2 = (n & (n - 1)) == 0;

// 3. 交换两个数（不用临时变量）
int a = 5, b = 3;
a ^= b; b ^= a; a ^= b;    // a=3, b=5

// 4. 快速取模（n 为正时）
int mod = n & (m - 1);     // m 为 2 的幂

// 5. 提取/设置某一位
int flag = 1 << 20;        // 第 20 位
boolean on = (n & flag) != 0;
n |= flag;                 // 置位
n &= ~flag;                // 清位
```

**移位运算符的细节**

《面渣逆袭 Java 基础篇》与《面试题-01》都强调 `>>` 与 `>>>` 的区别：

```java
-8 >> 1;      // -4   算术右移，高位补符号位 1
-8 >>> 1;     // 2147483644   逻辑右移，高位补 0
```

`>>>` 只对 int/long 有意义（且不能用 `>>>` 作用于 byte/short，会先提升为 int）。

另外 `<<` 的移位数会取模：`1 << 33` 等价于 `1 << 1`（因为 `33 & 31 == 1`）。

**浮点数比较**

《面渣逆袭 Java 基础篇》建议：

```java
// 错误
if (d1 == d2) { }

// 正确
if (Double.compare(d1, d2) == 0) { }
// 或用 BigDecimal
```

**三元运算符与短路**

《二哥修订版《30天速通Java》暗黑版》指出三目运算符本质上是**短路**的——只会求值被选中的那个分支，这让它可以安全地做「惰性求值」：

```java
// 只有 flag 为 true 时才调用 expensive()
String s = flag ? expensive() : null;
```

**复合赋值的隐式强转**

《面渣逆袭 Java 基础篇》指出一个易错点：

```java
byte b = 10;
b += 1;      // OK —— 编译器帮你做了 (byte)(b + 1)
b = b + 1;   // 编译错误！b + 1 是 int，不能赋给 byte
```

`+=` 之所以能编译通过，是因为它被定义为「先按二元运算计算，再隐式强转回左侧类型」。而 `b++` 也是可以的（编译器特殊处理）。

## 实战提示

**运算符使用规范**：

- 复杂表达式一律加括号（可读性 >> 优先级记忆）
- 浮点比较用 `Double.compare`
- 除法前检查分母（整数除零会抛异常）
- 移位位数确保在合法范围（`& 31` 或 `& 63`）
- 涉及金额的除法，明确指定精度与舍入模式：

```java
BigDecimal result = amount.divide(count, 2, RoundingMode.HALF_UP);
```

**位运算的适用边界**：只在**性能敏感的热点路径**或**位图/状态压缩**场景使用。普通业务代码用位运算会显著降低可读性，收益却很有限——现代 JIT 对 `n % 2` 与 `n & 1` 的优化几乎无差别。

**switch 与运算符配合**：《java实战演练35讲》里提到用位运算做状态压缩的经典模式：

```java
// 用一个 int 表示 32 个开关
int flags = 0;
flags |= 1 << 0;    // 打开第 0 个
flags |= 1 << 3;    // 打开第 3 个
boolean thirdOn = (flags & (1 << 3)) != 0;
```
' WHERE slug = 'operators';

-- control-flow
UPDATE lesson SET content = '## 本节要点

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
' WHERE slug = 'control-flow';

-- arrays
UPDATE lesson SET content = '## 本节要点

数组是**定长**的同类元素容器，声明时类型就固定了。关键点：数组是引用类型（可以赋给 Object）、长度不可变、多维数组本质是「数组的数组」、数组元素没有类型安全检查（可存 null 与任意子类型）。

## 核心概念

- **定长**：创建后长度不可变，扩容需新建数组并拷贝。
- **数组是引用类型**：`int[] a = new int[3]` 分配的是**引用**（对象），不是数组本身。
- **默认值**：数值 0、char `\u0000`、boolean false、引用 null。
- **数组变量 vs 数组对象**：`int[] a = new int[3]` 中 a 是引用，指向数组对象。
- **一维数组**：连续内存，元素按下标访问 O(1)。
- **多维数组**：`int[][] a = new int[2][3]` 实际是「一个长度为 2 的数组，每个元素是长度为 3 的数组」。**外层可为空，内层不可**（`new int[2][]` 合法但 `new int[2][3]` 不合法时内层不可 null 访问）。
- **Arrays 工具类**：sort、binarySearch、copyOf、fill、equals、hashCode、stream。
- **数组协变**：`Object[] arr = new String[1]` 合法，但 `arr[0] = 1` 会抛 ArrayStoreException。
- **数组的 clone()**：浅拷贝（对基本类型是深拷贝，对引用元素是浅拷贝）。
- **变长参数**：`void f(int... args)` 编译为 `void f(int[] args)`。
- **数组不是泛型**：不能 `List<int>`，但可以用 `List<Integer>` 或 `Arrays.asList` 包装。
- **Arrays.asList 的固定长度**：返回的是视图，不能 add/remove。

## 关键代码

```java
// 声明与初始化
int[] a = new int[3];                    // 默认全 0
int[] b = {1, 2, 3};                     // 简洁写法
int[] c = new int[]{1, 2, 3};

// 数组是引用类型
Object[] obj = new String[2];            // 数组协变，合法
obj[0] = "str";
// obj[1] = 123;                        // ArrayStoreException

// 长度不可变 —— 扩容要新建
int[] big = Arrays.copyOf(a, 10);

// 二分查找（必须先排序）
int[] sorted = {1, 3, 5, 7, 9};
Arrays.sort(sorted);
int idx = Arrays.binarySearch(sorted, 5);   // 2

// 填充与比较
Arrays.fill(sorted, 0);
boolean same = Arrays.equals(new int[]{1,2}, new int[]{1,2});

// 克隆：基本类型是深拷贝
int[] orig = {1, 2, 3};
int[] copy = orig.clone();
copy[0] = 99;
System.out.println(orig[0]);             // 1 —— 不受影响

// 多维数组
int[][] grid = new int[2][3];
grid[0][1] = 5;
System.out.println(grid.length);         // 2  —— 外层长度
System.out.println(grid[0].length);      // 3  —— 内层长度

// 变长参数
static int sum(int... nums) {
    int s = 0;
    for (int n : nums) s += n;
    return s;
}
sum(1, 2, 3);
sum();                     // 空数组

// 数组 → List
List<Integer> list = Arrays.asList(1, 2, 3);   // 固定长度视图
// list.add(4);                               // UnsupportedOperationException
List<Integer> mutable = new ArrayList<>(Arrays.asList(1, 2, 3));

// 数组流
int[] nums = {1, 2, 3, 4};
Arrays.stream(nums).sum();
int[] evens = Arrays.stream(nums).filter(n -> n % 2 == 0).toArray();
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 `int[] a = new int[3]` 直接分配了 3 个 int 的空间——先分配引用（数组对象），元素在堆上
- 多维数组 `arr.length` 取到的是元素个数而非总元素数
- 用 `Arrays.asList` 的结果调用 add/remove
- 以为 `arr[0] = null` 对基本类型数组合法——编译报错
- 混淆 `clone()` 的深浅拷贝
- 二分查找前忘记排序

## 动手练习

实现一个二维数组的矩阵乘法，并对比用三重循环与用 Stream 的可读性差异。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Java编程思想第四版》《面渣逆袭 Java 基础篇》《二哥修订版《30天速通Java》暗黑版》《面试题-01-Java基础知识面试题》《hello-algo_1.2.0_zh_java.pdf》对本节有覆盖。

**《Java编程思想第四版》第 8 章：数组**

这本书把数组与「类型安全」作为核心议题，指出 Java 数组的最大特点是**类型安全且自动检查**（对比 C/C++）：

- 数组只能是单一类型的对象或基本类型
- 编译器确保数组里装的元素类型正确
- 但数组**不是泛型**——`List<int>` 非法，只能用 `List<Integer>`

书中指出数组的**协变**特性：

```java
Object[] objects = new String[2];   // 合法
objects[0] = new Integer(1);        // 运行时 ArrayStoreException
```

**为什么会有协变**：Java 的类型转换规则允许子类数组向上转型为父类数组（类似协变返回类型），代价是失去了编译期的完全检查。

**《Java编程思想第四版》第 11 章：数组的初始化**

书中指出「数组本质上就是一组相同类型的变量」，而**基本类型数组与对象数组的内存布局不同**：

- `int[]`：连续存放 int 值，无对象头
- `Integer[]`：连续存放**引用**，每个 Integer 对象另占内存

因此在处理大量数字时，`int[]` 比 `Integer[]` 省内存得多。书中给出的替代方案是 `ArrayList` 的特化版本 `IntArrayList`（Guava 提供）。

**可变参数的实现**

《面渣逆泽 Java 基础篇》与《二哥修订版《30天速通Java》暗黑版》指出：

```java
void f(int... args) { }
// 编译后等价于
void f(int[] args) { }
```

调用 `f(1, 2, 3)` 时编译器会**新建一个数组**再传入——所以可变参数在高频调用路径上有额外开销，且**只能出现在参数列表的最后**。

**Arrays 工具类**

《java实战演练35讲》与《二哥修订版《30天速通Java》暗黑版》都强调两个常用方法：

```java
// 二分查找：前提是已排序
int[] arr = {1, 3, 5, 7, 9};
Arrays.sort(arr);
int i = Arrays.binarySearch(arr, 7);      // 3

// copyOf：扩容并保留原内容
int[] bigger = Arrays.copyOf(arr, 10);    // 后 5 个为 0
```

**《hello-algo》对数组的定位**

《hello-algo_1.2.0_zh_java》（算法教程）把数组定位为「最基础的数据结构」，并强调：

- 数组元素在内存中**连续存放**，支持随机访问（O(1)）
- 但「在中间插入/删除」需要移动后续元素，代价 O(n)
- 因此**查找用数组、插入删除用链表**是经典权衡

这解释了为什么 Java 集合框架里 ArrayList 与 LinkedList 都要有。

**数组排序**

《面渣逆袭 Java 基础篇》指出 `Arrays.sort` 对基本类型与对象的行为不同：

```java
int[] nums = {5, 2, 8};
Arrays.sort(nums);                       // 双轴快排（基本类型）

String[] names = {"pear", "apple"};
Arrays.sort(names);                     // 对象数组：调用 compareTo（TimSort）
Arrays.sort(names, (a, b) -> a.length() - b.length());   // 自定义比较器
```

**对象数组排序依赖 Comparable/Comparator**，这也是 Collections.sort 的实现基础。

**数组的浅拷贝问题**

《面渣逆袭Java基础篇V2.0（暗黑）》指出：

```java
int[][] matrix = {{1, 2}, {3, 4}};
int[][] copy = matrix.clone();     // 浅拷贝！
copy[0][0] = 99;
System.out.println(matrix[0][0]); // 99 —— 内层数组是共享的
```

深拷贝需要逐层克隆或用 `Arrays.deepToString` / `deepEquals` 系列方法。

**《面试题-01-Java基础知识面试题》的数组考点**

同一份资料把数组相关的考点归纳为：

- 数组的定义与初始化方式
- 数组的默认值
- 数组的长度（length 属性，不可改变）
- 数组的遍历方式（for / for-each / Arrays.stream）
- 数组排序与查找
- 二维数组的定义与遍历
- 数组与集合的转换

**数组与集合的转换**

《二哥修订版《30天速通Java》暗黑版》与《面渣逆袭 Java 基础篇》给出双向转换：

```java
// 数组 → List
List<String> list = Arrays.asList(arr);            // 固定长度视图
List<String> list2 = new ArrayList<>(Arrays.asList(arr));   // 可变副本
List<String> list3 = Arrays.stream(arr).toList();  // Java 16+，不可变

// List → 数组
String[] arr2 = list.toArray(new String[0]);
String[] arr3 = list.toArray(String[]::new);        // 推荐的写法

// 基本类型数组 → 流
int[] nums = {1, 2, 3};
int sum = Arrays.stream(nums).sum();
```

## 实战提示

**数组选型建议**：

| 需求 | 选择 |
| --- | --- |
| 元素类型固定、数量已知、追求性能 | 数组 |
| 需要动态增删 | ArrayList |
| 大量数字、内存敏感 | 基本类型数组 |
| 需要泛型 | List\<T\>（用包装类型） |

**常见陷阱清单**：

```java
// 1. 数组长度是属性不是方法
int len = arr.length;      // [OK] 没有括号

// 2. 基本类型数组不能存 null
// int[] a = {1, null};    // 编译错误

// 3. 遍历时修改长度会异常
for (int i = 0; i < arr.length; i++) {
    arr = Arrays.copyOf(arr, arr.length + 1);   // 危险！length 被重新求值
}

// 4. 多维数组要逐层判空
if (grid != null && grid[0] != null) { ... }
```

**性能提示**：数组是 JVM 优化最好的容器——访问可以完全消除边界检查（前提是循环边界已知）。因此在超热路径上，数组往往比 List 更快。

**但要注意**：Java 的 `List.remove(int)` 与 `List.remove(Object)` 重载差异是新手 bug 高发地——`list.remove(1)` 删的是**下标 1**，不是值为 1 的元素。数组没有这个问题，这也是数组更"安全"的一个理由。
' WHERE slug = 'arrays';

-- project-guess-number
UPDATE lesson SET content = '## 本节要点
综合运用分支与循环，写一个可交互的小游戏。

## 核心概念
- 用Random.nextInt 生成随机数的正确姿势
- 循环终止条件与次数控制
- 难度分级如何用参数表达

## 关键代码
```
import java.util.Random;
import java.util.Scanner;

public class GuessNumber {
    public static void main(String[] args) {
        Random rnd = new Random();
        int target = rnd.nextInt(100) + 1;   // 注意是左闭右开
        Scanner sc = new Scanner(System.in);

        for (int i = 1; i <= 7; i++) {
            System.out.print("第 " + i + " 次猜测：");
            int guess = sc.nextInt();
            if (guess == target) {
                System.out.println("猜对了！一共用了 " + i + " 次");
                return;
            }
            System.out.println(guess < target ? "太小了" : "太大了");
        }
        System.out.println("次数用完了，正确答案是 " + target);
    }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区
- [''用 nextInt(100) 却期望能取到 100，忘记右端点不包含'', ''把 Scanner 写完不关闭，在部分环境下会阻塞'']

## 动手练习
给游戏加三个难度：简单 1~50 七次、中等 1~100 十次、困难 1~500 五次。
' WHERE slug = 'project-guess-number';

-- string
UPDATE lesson SET content = '## 本节要点

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
for (int i = 0; i < 1000; i++) sb.append(i).append('','');
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
s.strip();                     // Java 11+，去首尾空白（比 trim 更全，trim 只去 <= '' ''）
s.lines().count();             // Java 11+，按行流
s.repeat(3);                   // Java 11+
s.chars().forEach(c -> ...);   // 按 char
"a-b-c".chars().mapToObj(c -> String.valueOf(c)).collect(Collectors.joining());
String.valueOf(65);            // 转字符串
```

**字符串与字符数组**

《面渣逆袭 Java 基础篇》指出 `char` 与 `String` 的转换：

```java
char c = ''a'';
String s1 = String.valueOf(c);        // 推荐
String s2 = c + "";                   // 能用但不优雅（c + "" 实际是 int + String）
String s3 = new String(new char[]{''a'',''b''});   // 从字符数组建字符串
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
for (String p : parts) sb.append(p).append('','');

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
' WHERE slug = 'string';

-- methods
UPDATE lesson SET content = '## 本节要点

方法是一段有名字、有参数、有返回值的代码块。Java 的方法传递**永远是值传递**——对象传的是引用值的拷贝。理解这一点，就理解了为什么在方法里"修改对象字段"有效，而"重新赋值形参"无效。

## 核心概念

- **方法签名**：`方法名 + 参数列表`（不含返回类型）。`重载`由签名决定，`重写`由签名 + 继承关系决定。
- **值传递（Java 只有值传递）**：基本类型传值的拷贝；对象传的是**引用值的拷贝**。
- **重载（Overload）**：同一类中多个同名方法，参数列表不同。编译期确定。
- **重写（Override）**：子类重新实现父类方法。运行时确定（多态）。
- **可变参数（Varargs）**：`int... args` 等价于 `int[] args`，必须放最后。
- **参数传递的"引用值拷贝"**：形参指向同一个对象，所以改字段有效；但给形参重新赋值不影响实参。
- **final 参数**：方法内不可重新赋值（Lambda 捕获的前提）。
- **静态方法**：属于类，this 不可用，不能重写（只能隐藏）。
- **方法引用**：`::` 是 Lambda 的简写形式。
- **递归**：自己调用自己，需要**递归终止条件**。
- **返回值类型协变**：重写时子类可返回更具体的类型（JDK 5+）。
- **调用栈**：每次方法调用压入一个栈帧，递归过深会 StackOverflowError。

## 关键代码

```java
// 值传递的本质
static void modify(Person p) {
    p.setName("changed");   // [OK] 有效 —— 改的是同一个对象
    p = new Person("new");  // [X] 无效 —— 只改了形参这个引用
}

static void modifyInt(int n) {
    n = 100;                // [X] 无效 —— 形参是值的拷贝
}

// 重载：参数列表不同
static int add(int a, int b) { return a + b; }
static double add(double a, double b) { return a + b; }
static int add(int a, int b, int c) { return a + b + c; }

// 可变参数
static int sum(int... nums) {
    int s = 0;
    for (int n : nums) s += n;
    return s;
}
sum(1, 2, 3);
sum(new int[]{1, 2, 3});   // 也可以直接传数组

// 方法引用（Lambda 简写）
Function<String, Integer> len = String::length;
Supplier<ArrayList<String>> factory = ArrayList::new;
BiFunction<String, String, Boolean> eq = String::equals;

// 静态方法 vs 实例方法
static void staticMethod() { }    // 属于类
void instanceMethod() { }         // 属于实例

// 递归：必须有终止条件
static long factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

// 尾递归在 Java 中不会被优化成循环
static int sum(int n, int acc) {
    if (n == 0) return acc;
    return sum(n - 1, acc + n);   // Java 不做尾递归优化
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 Java 对象参数是「引用传递」——是**引用值的值传递**
- 在方法里给形参重新赋值以为会影响实参——不会
- 混淆重载与重写——重载是编译期，重写是运行时
- 递归没有终止条件——StackOverflowError
- 以为可变参数能放在参数列表中间——必须放最后
- 在静态方法里用 this——编译错误

## 动手练习

写一个方法接收 List<Integer> 并原地排序，再写一个返回新 List 的版本，对比两者的语义差异与调用方感受。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭 Java 基础篇》《面渣逆袭Java基础篇V2.0（暗黑）》《二哥修订版《30天速通Java》暗黑版》《Effective+Java+中文第二版》《面试题-01-Java基础知识面试题》对本节有完整覆盖。

**Java 只有值传递**

《面渣逆袭 Java 基础篇》与《Effective Java》第 53 条都强调这一点，很多教材说"Java 是引用传递"是**不准确的**。

准确的说法：传递的是**引用值的拷贝**。因此：

```java
class Person { String name; }

static void test() {
    Person p = new Person("a");
    change(p);
    System.out.println(p.name);   // "changed" —— 对象本身被改了
}

static void change(Person p) {
    p.name = "changed";           // 改的是堆里的对象
    p = new Person("b");          // 形参指向新对象，不影响调用方的 p
}
```

《Effective Java》中把这种「引用值的拷贝」比作 **C++ 的引用**与 **Pascal 的指针**，但强调 Java 的差别在于**不能重新赋值**（Java 没有 `var x: T` 这样的引用形参语法）。

**《Effective Java》第 51 条 / 第 52 条：方法签名与可变参数**

《Effective Java》给出的签名规则：

- **不要修改已发布 API 的方法签名**——包括参数类型、顺序、名称、返回值
- **不要返回数组**——应该返回 List 或集合（数组可变，调用方能改坏内部状态）
- **不要为参数传入可变对象**——防御性拷贝
- **可变参数应放最后**，且**不要直接传可变数组引用**：

```java
// 危险：调用方能修改数组内容
static void foo(int... args) { }
int[] arr = {1, 2, 3};
foo(arr);
arr[0] = 99;    // foo 内部看到的值也变了
```

**重载与重写的判定**

《面渣逆袭 Java 基础篇》给出的判定方法：

| | 重载 | 重写 |
| --- | --- | --- |
| 发生范围 | 同一个类中 | 父子类之间 |
| 参数列表 | 必须不同 | 必须相同 |
| 返回类型 | 可任意 | 相同或协变 |
| 访问权限 | 无限制 | 不能更严格 |
| 绑定时机 | 编译期（静态） | 运行时（动态） |

一个常见陷阱：**子类中定义了与父类同名但参数不同的方法，那不是重写而是重载**，且会「遮蔽」父类的同名方法。

**《Effective Java》第 52 条：可变参数的防御性拷贝**

书中给出的安全写法：

```java
static void foo(int... args) {
    // 内部使用时先拷贝，防止调用方在方法执行期间修改数组
    int[] copy = args.clone();
}
```

**尾递归与栈溢出**

《面渣逆袭Java基础篇V2.0（暗黑）》指出 Java **不做尾递归优化**，所以尾递归同样会消耗栈帧：

```java
// 深度 10000 的递归 → StackOverflowError
static int sum(int n, int acc) {
    if (n == 0) return acc;
    return sum(n - 1, acc + n);
}
```

书中的建议是把递归改写成循环：

```java
static int sumIterative(int n) {
    int acc = 0;
    for (int i = 1; i <= n; i++) acc += i;
    return acc;
}
```

**《Effective Java》第 4 条：不要设计长度为 0 的方法**

书中建议用静态工厂方法替代返回 null 的方法：

```java
// 不推荐
static Person findById(String id) { return null; }

// 推荐：空对象模式
static Person findById(String id) {
    Person p = repo.find(id);
    return p != null ? p : Person.EMPTY;   // 空对象，让调用方无需判空
}
```

**方法引用与 Lambda 的等价性**

《二哥修订版《30天速通Java》暗黑版》给出了对照：

```java
// 三者等价
Function<String, Integer> f1 = s -> s.length();
Function<String, Integer> f2 = String::length;
Function<String, Integer> f3 = s -> s.length();   // 同 f1
```

四种方法引用的形式：

```java
Supplier<ArrayList<String>> s1 = ArrayList::new;              // 构造器引用
Function<String, Integer> f1 = String::length;                // 实例方法引用
BiFunction<String, String, Boolean> f2 = String::equals;      // 实例方法引用（带参数）
Function<String, Integer> f3 = Integer::parseInt;            // 静态方法引用
```

**《Effective Java》第 58 条：局部变量作用域最小化**

书中给出的实践：

```java
// 不好：变量作用域过大
int result;
for (int i = 0; i < list.size(); i++) {
    result = compute(list.get(i));
}

// 好：紧贴使用处
for (int i = 0; i < list.size(); i++) {
    int result = compute(list.get(i));
    use(result);
}
```

**《面试题-01-Java基础知识面试题》的方法相关考点**

- 方法重载与重写的区别
- Java 的参数传递机制（值传递）
- final 参数与 effectively final
- 静态方法与实例方法的区别
- 递归的原理与栈帧开销
- 可变参数的限制

## 实战提示

**返回值设计的建议**（Effective Java 第 7 条）：

| 需求 | 返回 |
| --- | --- |
| 可能无结果 | `Optional<T>` |
| 多个结果 | 专用的 DTO / record |
| 集合 | 返回 `List`/`Set`，不要返回数组 |
| 布尔 | 直接返回 boolean，不要返回 Boolean |

**方法长度的建议**（Effective Java 第 43 条）：方法应短小、职责单一。一个好用的检验标准是——**如果方法需要用注释来解释「哪几步在做什么」，就该拆分了**。

**不要返回数组**（Effective Java 第 52 条）：

```java
// 不好：调用方能改坏内部状态
static String[] getNames() { return names.clone(); }

// 好
static List<String> getNames() { return List.of(names); }
```

**性能提示**：方法调用本身在 JIT 后是内联的，热路径上不必担心方法调用开销。但**别用小方法去替代清晰的代码结构**——Java 没有 inline 提示，方法太多反而影响 JIT 的内联决策（默认只内联小于 35 字节的热点方法）。
' WHERE slug = 'methods';

-- class-and-object
UPDATE lesson SET content = '## 本节要点

`equals` 与 `hashCode` 必须**同时重写且保持一致**——这是 Java 里最容易被违反的契约。不可变对象（Immutable）是设计的基石：天然线程安全、可安全共享、可作为缓存 key。

## 核心概念

- **equals 契约**：自反性、对称性、传递性、一致性、非 null。
- **hashCode 契约**：相等对象必须哈希码相等；哈希码相等的对象**不一定**相等（允许碰撞）。
- **两者关系**：hashCode 相等是 equals 相等的**必要条件**（用于哈希桶定位），不是充分条件。
- **对象标识 vs 值相等**：`==` 比较引用，`equals` 比较逻辑值。
- **不可变对象**：所有字段 final、构造后状态不变、不暴露内部引用（防御性拷贝）。天然线程安全。
- **防御性拷贝**：可变对象作为参数/返回值时拷贝一份，避免外部篡改内部状态。
- **构造器不暴露 this**：构造器中不应调用可被重写的方法（this 尚未完全初始化）。
- **静态工厂方法 vs 构造器**：可以返回缓存实例、可以有清晰命名、可绕过构造器限制。
- **享元（Flyweight）**：不可变 + 共享实例 + 外部状态外置。

## 关键代码

```java
// equals 与 hashCode 必须一起重写
final class Point {
    private final int x, y;
    Point(int x, int y) { this.x = x; this.y = y; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Point p)) return false;
        return x == p.x && y == p.y;
    }

    @Override
    public int hashCode() {
        return Objects.hash(x, y);   // 与 equals 保持一致
    }
}

// 不可变对象 + 防御性拷贝
final class Period {
    private final Date start;   // 不可变对象本身才能这样声明
    Period(Date start) { this.start = new Date(start.getTime()); }  // 拷贝
    Date start() { return new Date(start.getTime()); }              // 返回拷贝
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 只重写 equals 不重写 hashCode，导致放进 HashMap 后 get 不到
- 用 `getClass() != o.getClass()` 判断类型，破坏了对称性（子类会出问题）
- 认为 `==` 对 String 也成立——只有常量池中的字面量才成立
- 在不可变类里返回一个可变成员的引用，破坏不可变性

## 动手练习

实现一个不可变的 `Money` 类（金额 + 币种），重写 equals/hashCode，放入 HashSet 验证去重与查找。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Effective+Java+中文第二版》《二哥的 Java 进阶之路暗黑版》《面渣逆袭 Java 基础篇》《深入浅出Java+23种设计模式》对本节原则有系统论述。

**Effective Java 第 3 条：永远不要覆盖 equals 和 hashCode**

《Effective Java 中文第二版》共 57 条经验规则，第 3 条专门讲这件事。核心结论：

- 覆盖 equals 时**必须同时覆盖 hashCode**，否则违反 hashCode 契约
- 唯一的例外是**不可变对象**——因为它的哈希码计算结果不会变

书中给出的「equals 的实现套路」（Effective Java 第 3 条 + 第 12 条）：

```java
@Override
public boolean equals(Object o) {
    if (o == this) return true;                 // 引用检查（快路径）
    if (!(o instanceof MyType)) return false;   // 类型检查
    MyType other = (MyType) o;
    // 逐字段比较
}
```

**为什么 instanceof 而不是 getClass()**

《Effective Java》第 12 条（覆写 equals 时请遵循约定）与《二哥的 Java 进阶之路》都讨论了这个细节：

- `instanceof` 允许**子类与父类对称**（对称性）
- `getClass() != o.getClass()` 严格相等，破坏了「父类引用指向子类对象」时的对称性
- 但 `instanceof` 有个坑：若父类是可变的、且有额外字段，子类只比较父类字段就会漏判

书中给出的最佳实践：**把类设计成 final，或者把 equals 声明为 final**，避免子类破坏契约。

**Effective Java 第 17 条：使对象不可变**

《Effective Java 中文第二版》给出了不可变对象的五条设计准则：

1. 不要修改可观察到的对象状态
2. 不要暴露内部可观察到的状态
3. 构造器与字段都设为 final
4. 不要让被访问的字段成为可变对象
5. 若类不可变，则所有可变组件的访问器都必须返回防御性拷贝

**第 4 条与第 5 条的实用价值**：

```java
// 不可变类中持有可变字段时
private final List<String> items;

// 错误：直接暴露
public List<String> items() { return items; }

// 正确：防御性拷贝
public List<String> items() { return List.copyOf(items); }
```

**第 13 条：避免使用可变对象作为字段**

《Effective Java》第 13 条讨论了可变对象作为静态字段的风险：若可变对象被用作静态字段，它的状态会被整个 JVM 共享，任何线程都能修改它。书中建议：

- 不可变对象可安全共享
- 可变对象应尽量限制为**单个线程**使用

**Effective Java 第 15 条 / 第 16 条：防御性拷贝**

书中强调：即使类的组件是不可变的，把**可变对象**传入构造器或从方法返回时，仍应考虑防御性拷贝——因为我们无法保证调用方不会持有并修改那个引用。

**静态工厂方法的优势**

《Effective Java》第 2 条（考虑用静态工厂方法替代构造器）列举了静态工厂的四个优势：

1. **可以有清晰的名字**——构造器只能与类同名
2. **可以返回缓存实例**——`Integer.valueOf` 复用 -128~127 的缓存
3. **可以返回子类型**——构造器做不到
4. **可以绕过构造器的参数限制**——私有构造器 + 静态工厂可控制实例化

《二哥的 Java 进阶之路》也提到 `valueOf` 的缓存机制。

**不可变对象与享元模式**

《深入浅出Java+23种设计模式》中的享元模式（Flyweight）与不可变对象天然契合：把可共享的部分做成不可变并共享，把不可共享的状态作为外部参数传入。《二哥的 Java 进阶之路》与《Effective Java》都提到 String 内部就是享元模式的经典实现。

## 实战提示

**重写 equals/hashCode 的检查清单**：

| 检查项 | 说明 |
| --- | --- |
| equals 的类型判断 | 用 `instanceof` 或 `getClass()`，且要与继承体系匹配 |
| 字段一致性 | equals 中比较的字段，hashCode 中也要用 |
| hashCode 实现 | 用 `Objects.hash(...)` 保证与 equals 一致 |
| 可继承类 | equals/hashCode 考虑声明为 final，防止子类破坏契约 |

**IDE 自动生成后务必人工复核**：IDE 生成的模板默认用 `getClass()`，在有继承关系的类中需要改成 `instanceof`。

**不可变类的实用收益**：

```java
// 不可变对象可安全作为 HashMap 的 key，无需考虑并发修改
Map<UserKey, Profile> cache = new ConcurrentHashMap<>();
```

不可变对象还有三个额外好处：可安全发布（final 字段有内存语义保证）、可缓存（对象一旦创建状态不再变化）、易于测试（无隐藏状态）。

**防御性拷贝的适用场景**：只有当**可变对象**被传入/返回时才需要。传 `String`、`Integer` 等本身不可变对象时不需要拷贝——多拷贝一次纯属浪费。
' WHERE slug = 'class-and-object';

-- oop-core
UPDATE lesson SET content = '## 本节要点

面向对象三大支柱是**封装、继承、多态**。Java 的实现机制：字段与方法用 `private` 隐藏（封装）、`extends` 建立 is-a 关系（继承）、方法重写 + 运行时多态（多态）。继承最大的问题是**脆弱基类**——基类改动会波及所有子类。

## 核心概念

- **封装**：隐藏内部实现，通过方法暴露访问。降低耦合、允许内部自由演进。
- **继承**：复用代码 + 建立 is-a 关系。Java 单继承（类）+ 多实现（接口）。
- **多态**：父类引用指向子类对象，调用同一方法表现出不同行为。前提是**方法被重写**。
- **方法重写（Override）**：子类重新实现父类方法，签名相同。
- **方法重载（Overload）**：同一类中多个同名不同参的方法，与继承无关。
- **重写规则**：访问权限不能更严格、返回值协变、checked 异常不能更宽、final 不能重写、static 不能重写、private 不能重写。
- **协变返回类型**：JDK 5+ 支持，子类可返回更具体的类型。
- **组合优于继承**：用「has-a」组合代替「is-a」继承，避免脆弱基类。
- **里氏替换原则（LSP）**：子类必须能替换父类 wherever 父类被使用。
- **向上转型（Upcasting）** 与 **向下转型（Downcasting）**。
- **重写与重载的区分**：重写发生在父子类之间（运行时多态），重载发生在同一类中（编译期多态）。

## 关键代码

```java
class Animal {
    void speak() { System.out.println("..."); }
    protected void breathe() { }              // protected：子类可见
    private void hidden() { }                 // private：子类不可见
    final void cannotOverride() { }           // final：禁止重写
    static void staticMethod() { }            // static：隐藏而非重写
}

class Dog extends Animal {
    @Override
    void speak() { System.out.println("汪"); }   // 访问权限不能更严格

    // 协变返回类型：返回更具体的类型
    @Override
    Dog clone() { return new Dog(); }
}

// 运行时多态
Animal a = new Dog();
a.speak();          // 输出「汪」——实际调用 Dog.speak()

// 向下转型
if (a instanceof Dog d) {
    d.bark();        // Java 16+ 模式匹配
}

// 组合优于继承
class Engine { void start() {} }
class Car {
    private final Engine engine = new Engine();   // has-a
    void drive() { engine.start(); }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为重载是「多态」——重载是编译期静态绑定，只有重写才是运行时多态
- 认为子类能访问父类的 private 字段——只能通过父类的 public/protected 方法间接访问
- 用 `instanceof` 层层判断代替多态——这是「面向对象之反模式」
- 继承层次过深，导致「脆弱基类」问题

## 动手练习

用继承实现 `Animal → Dog / Cat`，再用组合重写同一个需求，对比两种方案在需求变更时的改动量。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Effective+Java+中文第二版》《深入浅出Java+23种设计模式》《深入设计模式》《二哥的 Java 进阶之路暗黑版》对本节原则有深度覆盖。

**Effective Java 第 16 条：优先使用组合而非继承**

《Effective Java 中文第二版》第 16 条讨论继承的缺陷：

- **脆弱基类（Fragile Base Class）**：继承的实现细节可能变化，导致子类失效
- **无法阻止子类破坏约定**：子类可以覆盖父类方法，破坏 Liskov 替换原则
- **类的命名空间冲突**：继承会把父类的所有方法带入子类作用域

书中给的组合替代方案：

```java
// 继承：is-a
class LoggingArrayList<E> extends ArrayList<E> { ... }   // 脆弱

// 组合：has-a（装饰器模式）
class LoggingList<E> implements List<E> {
    private final List<E> delegate;
    @Override public boolean add(E e) {
        System.out.println("adding " + e);
        return delegate.add(e);
    }
    // 其余方法全部转发
}
```

《Effective Java》第 18 条建议：**用组合代替继承**。

**里氏替换原则的具体体现**

《深入设计模式》与《Effective Java》都强调：继承必须保证「子类在语义上确实是父类」。反例是经典的「正方形不是矩形」：

```java
class Rectangle {
    void setWidth(int w) { ... }
    void setHeight(int h) { ... }
}
class Square extends Rectangle {
    @Override void setWidth(int w) { setHeight(w); }   // 破坏 LSP
}
```

《深入浅出Java+23种设计模式》给出的解决方案是**组合 + 抽象接口**，让正方形不继承矩形。

**重写规则的完整清单**

《二哥的 Java 进阶之路暗黑版》与《Effective Java》都整理了重写的约束：

| 规则 | 说明 |
| --- | --- |
| 返回类型 | 相同或协变（JDK 5+） |
| 访问权限 | 不能比父类更严格（protected → public 可以，反之不行） |
| 受检异常 | 不能抛出比父类更宽的异常 |
| final 方法 | 不能重写 |
| static 方法 | 只能隐藏（hide），不是重写 |
| private 方法 | 不参与继承，子类可定义同名方法（不是重写） |
| final 类 | 不能被继承 |

**重写与重载的判定**

《二哥的 Java 进阶之路》给出的判断方法：

- **重写**：发生在父子类之间，方法签名相同，运行时动态分发
- **重载**：同一类中，参数列表不同，编译期静态绑定

一个常见误解是「重载也是多态」——准确说重载是**编译期多态**（静态绑定），重写才是**运行时多态**（动态绑定）。

**构造器中调用可重写方法的问题**

《Effective Java》第 9 条（构造器调用可重写的类方法）指出：构造器中调用 `this` 或可被重写的方法时，子类的重写版本会被调用，而此时**子类的字段还没初始化**，会导致读到默认值（null / 0）。

```java
class Bad extends Base {
    private final String name = "initialized";
    Bad() {
        super();                 // 父类构造器若调用可重写方法
    }
    @Override String getName() { return name; }   // 此时 name 还是 null！
}
```

**模板方法模式（Template Method）**

《深入浅出Java+23种设计模式》给出的经典解决方案是 Template Method：把可变步骤抽成抽象方法，由父类的模板流程控制调用顺序。

## 实战提示

**多态的实战价值**：

```java
// 调用方只面向抽象编程，不需要 if-else 判断类型
void process(List<Animal> animals) {
    for (Animal a : animals) {
        a.speak();       // 各自表现不同行为
    }
}
```

新增物种时**不需要修改调用方**——这是开闭原则（OCP）的体现。

**组合优于继承的判断标准**：如果被继承的类来自第三方库、或继承层次超过 2 层、或父类有可变字段，优先用组合。

**协变返回类型的实用场景**：

```java
// 替代克隆模式
class Node {
    Node copy() { return new Node(); }
}
class SpecialNode extends Node {
    @Override SpecialNode copy() { return new SpecialNode(); }  // 返回更具体
}
```

**静态方法与实例方法的隐藏/重写区别**：

```java
class Parent { static void s() {} void i() {} }
class Child extends Parent {
    static void s() {}     // 隐藏（hide），不是重写
    @Override void i() {}  // 重写
}
Parent.s();   // 调 Parent 的 static
Child.s();    // 调 Child 的 static —— 编译期静态绑定
```
' WHERE slug = 'oop-core';

-- interface-vs-abstract
UPDATE lesson SET content = '## 本节要点

接口描述「能力」，抽象类描述「is-a 的共同实现」。接口可以有 default 方法与静态方法，抽象类可以有状态与构造器。**面向接口编程**是 Java 的核心原则之一。

## 核心概念

- **接口（interface）**：一组抽象方法的集合（JDK 8+ 可有 default / static / private 方法）。不能有实例字段（只能有常量）。
- **抽象类（abstract class）**：可以有抽象方法、实例字段、构造器。用 `abstract` 修饰。
- **核心区别**：接口是「can-do」（能力/角色），抽象类是「is-a」（本质上的共同种类）。
- **default 方法**：接口的默认实现，子类可重写。为接口演化留了后路（向后兼容）。
- **接口中的 static 方法**：只能通过接口名调用，不能被实现类继承。
- **接口中的 private 方法**（JDK 9+）：供 default 方法内部共享。
- **多继承**：类只能单继承，但可以实现多个接口，因此接口成了「多继承」的唯一途径。
- **抽象类不能多继承**：Java 单继承限制。
- **何时用哪个**：需要共享状态/构造器/非public 成员 → 抽象类；只需要能力契约 → 接口。
- **接口常量**：隐式 `public static final`。

## 关键代码

```java
// 接口：能力契约
interface Flyable {
    void fly();
    default boolean canLand() { return true; }   // 默认实现
    static Flyable bird() { return () -> {}; }   // 静态方法
    private void helper() { }                     // JDK 9+ 私有方法
}

// 抽象类：is-a + 共享状态
abstract class Shape {
    protected final String name;                 // 状态
    Shape(String name) { this.name = name; }     // 构造器
    abstract double area();
    public String describe() { return name + ": " + area(); }
}

class Circle extends Shape {
    private final double r;
    Circle(double r) { super("circle"); this.r = r; }
    @Override double area() { return Math.PI * r * r; }
}

// 多继承：实现多个接口
class Bird implements Flyable, Comparable<Bird> {
    @Override public void fly() { }
    @Override public int compareTo(Bird o) { return 0; }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为接口不能有实现——JDK 8 起可以有 default / static 方法
- 认为 default 方法不能重写——完全可以，且常用于接口间冲突消解
- 在接口中声明实例字段——接口字段隐式是 `public static final`
- 滥用抽象类，把「公共代码」当唯一理由——共享代码不该是继承的主要动机

## 动手练习

把「支付方式」建模成接口（支付宝/微信/银行卡），把「订单」建模成抽象类，观察两者的复用边界。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Effective+Java+中文第二版》《深入浅出Java+23种设计模式》《深入设计模式》《二哥的 Java 进阶之路暗黑版》《面渣逆袭 Java 基础篇》对本节有充分覆盖。

**Effective Java 第 17/18 条与接口优先原则**

《Effective Java 中文第二版》给出的明确建议：

| 场景 | 书中建议 |
| --- | --- |
| 需要继承 | **优先考虑接口** |
| 需要多继承 | 只能用接口 |
| 需要可变状态 | 只能用抽象类 |
| 需要非 public 成员 | 只能用抽象类 |
| 多个实现类共享代码 | 书中明确反对——「不要为复用而继承」 |

书中第 18 条的结论很直接：**优先使用接口，而不是抽象类**。理由是接口更灵活、实现类不受实现类层次结构的约束。

**《深入浅出Java+23种设计模式》对接口的定位**

这本书把接口作为「策略模式」的基础。典型用法：

```java
// 策略模式：把可变行为抽到接口
interface Strategy {
    void pay(int amount);
}
class AlipayStrategy implements Strategy {
    public void pay(int amount) { System.out.println("支付宝 " + amount); }
}
class Order {
    private Strategy strategy;         // has-a，比继承更灵活
    void checkout(int amount) { strategy.pay(amount); }
}
```

对比继承方式——如果用继承表达「不同支付方式」，每次新增支付方式就要新增子类，且无法在运行时切换；用组合（策略）则可以运行时注入。

**接口的 default 方法解决了什么问题**

《Effective Java》第 18 条提到接口演化的难题：如果接口新增抽象方法，所有实现类都会编译失败。default 方法的出现解决了这个「**源码兼容**」问题：

```java
interface Iterable {
    Iterator<E> iterator();
    default void forEach(Consumer<? super E> action) {
        for (E e : this) action.accept(e);   // 默认实现
    }
}
```

JDK 8 给 `Collection`、`Iterable`、`List` 等加了大量 default 方法，正是为了在**不破坏已有实现类**的前提下扩充 API。

**接口多继承的冲突处理**

《深入浅出Java+23种设计模式》指出，当一个类实现多个接口且它们有同名 default 方法时，会编译报错。解决方式有三：

```java
interface A { default void hello() { System.out.println("A"); } }
interface B { default void hello() { System.out.println("B"); } }

// 1. 类中重写（最常用）
class C implements A, B {
    @Override public void hello() { A.super.hello(); }   // 显式指定
}

// 2. 接口继承接口时消解
interface C extends A, B {
    @Override default void hello() { A.super.hello(); }
}
```

**抽象类与接口的运行时差异**

《二哥的 Java 进阶之路暗黑版》指出一个性能与设计的细节：接口的 default 方法在编译后是**接口上的方法**，调用时是 `invokeinterface`；而抽象类的方法是 `invokevirtual`。在极热的调用路径上，抽象类可能有微小的性能优势——但这几乎从不构成选择抽象类的理由。

**设计模式中的接口应用**

《深入设计模式》（Refactoring 经典）指出：接口在重构中扮演「**目标类型**」的角色。原书讨论「用接口替代具体类」这一重构手法时的理由是：

- 降低客户端对具体实现的依赖
- 可以在不修改客户端的前提下替换实现
- 让实现可以被多个客户端复用

**接口常量**

《二哥的 Java 进阶之路》指出接口中的字段隐式为 `public static final`，因此：

```java
interface Config {
    int MAX_RETRY = 3;      // 隐式 public static final
}
```

这类「常量接口」现在被广泛认为是不好的实践（Effective Java 第 19 条建议避免常量接口），因为它污染了实现类的命名空间。更好的做法是用枚举、final 类，或 `java.nio` 里的 `StandardCharsets` 这种独立常量类。
' WHERE slug = 'interface-vs-abstract';

-- final-static-immutable
UPDATE lesson SET content = '## 本节要点

`final` 表示不可继承/不可重写，`static` 表示属于类而非实例，`不可变对象`（Immutable）指构造后状态不再改变。三者组合是 Java 中最稳健的设计手法——不可变对象天然线程安全。

## 核心概念

- **final 字段**：只能赋值一次。构造器中对 final 字段赋值，编译器保证**正确发布**（其他线程看到构造好的对象，不会看到半初始化状态）。
- **final 与内存语义**：final 字段有「冻结」语义，JMM 保证构造完成后其它线程能看到正确值。这是 JSR-133 引入的关键修复。
- **static**：属于类，全类共享一份。static 方法不能直接访问实例成员。
- **static 初始化顺序**：静态字段与静态代码块按声明顺序执行，且在类加载（初始化）时执行一次。
- **类初始化触发条件**：new、访问静态字段/方法、反射、初始化子类。
- **不可变对象**：所有字段 final、不暴露内部状态、构造后不再变化。
- **不可变对象的好处**：线程安全（无共享可变状态）、可安全缓存、可作为 Map key、易于推理。
- **防御性拷贝**：可变对象进出不可变类时必须拷贝。
- **枚举的隐藏单例**：enum 天然是不可变单例。

## 关键代码

```java
// final 字段 + 正确发布
final class ImmutablePoint {
    private final int x, y;
    ImmutablePoint(int x, int y) { this.x = x; this.y = y; }
    int x() { return x; }
}

// static：类级别共享
class Config {
    static final int MAX_RETRY = 3;         // 常量：编译期内联
    static int counter = 0;                 // 可变静态字段（慎用）
    static {                                // 静态代码块：类初始化时执行
        counter = 10;
    }
    static void reset() { counter = 0; }    // static 方法不能访问实例成员
}

// 枚举：天然不可变单例
enum Status {
    ACTIVE, INACTIVE;
    boolean isActive() { return this == ACTIVE; }   // 有方法，但不能有可变字段
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 final 字段在构造后还能修改——final 引用不可变，但引用指向的对象仍可能变
- 认为 `static final` 常量一定在堆里——基本类型/String 常量会被编译期内联，不占运行时空间
- 认为不可变对象一定线程安全——前提是它的所有字段都是不可变的
- 忘了 static 字段在**多线程下的初始化竞争**（类初始化有锁保护，但初始化后的可见性靠 JMM 保证）

## 动手练习

实现一个不可变的 `UserId` 类（含校验、缓存），放入 HashMap 验证作为 key 的正确性。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Effective+Java+中文第二版》《二哥的 Java 进阶之路暗黑版》《面渣逆袭 Java 基础篇》以及《Java编程思想第四版》对本节有细致论述。

**Effective Java 第 17 条：不可变对象**

《Effective Java 中文第二版》第 17 条给出的五条准则（前文已列），其中最实用的是第 3 条与第 5 条：

- 构造器与字段都设为 final
- 若类不可变，所有可变组件的访问器都必须返回防御性拷贝

书中强调不可变对象的三重优势：

1. **线程安全**：不可变对象在多线程间共享是安全的，不需要同步
2. **可安全发布**：不可变对象的状态在构造后永不改变，因此可以在构造后任意时间安全地发布（甚至不用 volatile）
3. **可缓存**：可以缓存其哈希码，甚至缓存整个对象

**final 字段的正确发布语义（JSR-133）**

《二哥的 Java 进阶之路暗黑版》与《Effective Java》都提到 Java 5 引入的关键修复：**final 字段的安全发布保证**。

规则是：`this` 引用在构造函数中「逸出」之前，final 字段的值必须对其它线程可见。JMM 规定：

- 构造器中对 final 字段的写入，与「构造器结束」这个动作之间存在 happens-before 关系
- 因此其它线程一旦看到对象引用，就能看到正确的 final 字段值

```java
// 正确：final 字段安全发布
final class SafeHolder {
    private final int value = 42;      // final
    private int nonFinal = 0;          // 非 final —— 可能看到 0
}

// 错误：this 逸出
class Unsafe {
    Unsafe() {
        new Thread(() -> System.out.println(this.value)).start();  // 逸出！
    }
    private int value = 42;
}
```

**《Effective Java》第 83 条：只在名字不变时才用 final**

书中提醒：`final` 用在可变对象上会造成误导——`final List<String> list` 看起来不可变，实际 list 的内容仍可改。正确做法是**不暴露可变集合**：

```java
private final List<String> items = new ArrayList<>();

// 错误：返回可变引用
public List<String> items() { return items; }

// 正确：返回不可变视图
public List<String> items() { return Collections.unmodifiableList(items); }
// 或
public List<String> items() { return List.copyOf(items); }
```

**static 的语义与陷阱**

《二哥的 Java 进阶之路暗黑版》与《面渣逆袭 Java 基础篇》覆盖了 static 的几个要点：

- static 字段属于类，被所有实例共享，生命周期跟随类
- static 方法只能访问 static 成员，不能用 `this` / `super`
- static 初始化在**类初始化**时执行，且 JVM 保证类初始化的线程安全（由 JVM 对类的加载锁保证）
- `static` 与 `final` 同时修饰 → **编译期常量**，会被直接内联到调用方的字节码中

```java
static final int MAX = 100;
// 编译后调用方直接是常量 100，不读 Config.MAX 字段
```

**这带来一个陷阱**：修改 `static final` 常量的值后，**调用方需要重新编译**才能生效（因为已被内联）。运行时反射改字段也没用。

**枚举优于单例常量**

《Effective Java》第 22 条（用枚举代替常量）与《二哥的 Java 进阶之路》都推荐用 enum 表达一组常量：

```java
// 优于 static final 常量
enum Operation {
    PLUS, MINUS, MULTIPLY;
    // 可以有字段、构造器、方法 —— 常量做不到
}
```

enum 的额外好处：天然单例、线程安全、可用于 switch。

**《面渣逆袭 Java 基础篇》关于 final 的高频问题**

同一份资料把「final 关键字」列为高频考点，结论可以概括为：

- final 修饰基本类型 → 值不可变
- final 修饰引用 → **引用不可变**，指向的对象可变
- final 修饰方法 → 子类不可重写
- final 修饰类 → 不可被继承（如 `String`、`Integer`）
- final 修饰参数 → 方法内不可重新赋值（Lambda 中尤其常用）

## 实战提示

**不可变对象的落地模板**：

```java
final class Order {
    private final String id;
    private final List<Item> items;

    Order(String id, List<Item> items) {
        this.id = id;
        this.items = List.copyOf(items);      // 防御性拷贝 + 不可变
    }

    public String id() { return id; }
    public List<Item> items() { return items; } // 已是不可变，可直接返回
}
```

注意构造器里用 `List.copyOf` 一次性完成「拷贝 + 转为不可变」两件事，比手动 `new ArrayList<>()` 后再 `unmodifiableList` 更简洁且更安全。

**final 的实用场景**：

| 场景 | 说明 |
| --- | --- |
| 常量 | `static final` 是编译期常量，优于可被修改的 `static` |
| 线程安全发布 | 不可变对象不需要 volatile 或同步即可安全共享 |
| 禁止继承 | `final class` 防止子类破坏 equals/hashCode 契约（见 equals 课时） |
| Lambda 局部变量 | Effectively final 的变量才能被 Lambda 捕获（Java 8+） |

**枚举的隐藏优势**：

```java
enum Status {
    ACTIVE(1), INACTIVE(0);
    private final int code;
    Status(int code) { this.code = code; }
    public int code() { return code; }
}
```

enum 可以有构造器、实例字段、方法——这是 `static final` 常量做不到的，且天然线程安全（由 JVM 保证）。
' WHERE slug = 'final-static-immutable';

-- enum-and-record
UPDATE lesson SET content = '## 本节要点

`enum` 是 Java 特有的类型，天然是**单例**且**线程安全**。`record`（JDK 16+）是面向数据载体的语法糖，编译器自动生成构造器、访问器、equals/hashCode/toString。JDK 17 还引入了 **sealed 类**与**switch 模式匹配**。

## 核心概念

- **enum**：隐式继承 `java.lang.Enum`，每个常量是 enum 类型的单例实例。可有构造器、字段、方法，但不能有子类。
- **enum 的构造器是 private**：只能由 enum 自己调用。
- **抽象方法**：enum 可以实现抽象方法，每个常量分别实现——这是 enum 优于常量类的关键。
- **EnumMap / EnumSet**：针对 enum 的高性能实现（用位向量或数组，优于 HashMap/HashSet）。
- **record**：JDK 16 正式引入的不可变数据载体，隐式 `final`，组件是 `private final`。
- **record 的紧凑构造器**：可做校验与归一化。
- **record 是名义 final**：不能 extends，但可以实现接口。
- **sealed 类**（JDK 17）：`sealed` + `permits` 显式列出允许的子类，编译期约束继承关系。
- **sealed 的动机**：给「模式匹配 switch」提供穷尽性检查的前提。
- **switch 模式匹配**（JDK 17 预览 / JDK 21 正式）：`case Circle c -> ...`，可按类型与 guard 分支。
- **record 的限制**：不能继承其它类、不能声明额外实例字段（静态字段可以）。

## 关键代码

```java
// enum：可以有构造器、字段、方法，甚至抽象方法
enum Planet {
    MERCURY(3.3e23, 2.44e6), EARTH(5.97e24, 6.37e6);

    private final double mass, radius;

    Planet(double mass, double radius) {     // 隐式 private
        this.mass = mass;
        this.radius = radius;
    }

    double gravity() { return 6.67e-11 * mass / (radius * radius); }
}

// enum 实现抽象方法：每个常量各自实现
enum Operation {
    PLUS { public int apply(int a, int b) { return a + b; } },
    MINUS { public int apply(int a, int b) { return a - b; } };

    public abstract int apply(int a, int b);
}

// record：不可变数据载体
record Point(int x, int y) {
    // 紧凑构造器：做校验与归一化
    Point {
        if (x < 0) throw new IllegalArgumentException("x must be >= 0");
        if (y < 0) y = 0;                       // 可以重新赋值
    }
    int sum() { return x + y; }                // 可以有额外方法
}

// sealed：显式控制继承关系
sealed interface Shape permits Circle, Square {}
record Circle(double r) implements Shape {}
record Square(double side) implements Shape {}

// switch 模式匹配（JDK 21+）
static String describe(Object o) {
    return switch (o) {
        case Integer i when i > 100 -> "big int";
        case Integer i -> "int " + i;
        case Circle c -> "circle r=" + c.r();
        case null -> "null";
        default -> "other";
    };
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 enum 不能有构造器——可以，只是隐式 private
- 以为 record 会被序列化破坏——record 实现了 Serializable，但反序列化会绕过构造器
- 以为 record 可以继承其它类——不能（隐式继承 java.lang.Record）
- 忽略 sealed 的价值：它让编译器帮你在重构时检查「新增了子类但漏改 switch」

## 动手练习

用 enum 实现一个支付渠道（含各自的手续费计算），用 record 表示订单行项目。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《二哥的 Java 进阶之路暗黑版》《Effective+Java+中文第二版》《二哥修订版《30天速通Java》暗黑版》《深入浅出Java+23种设计模式》对本节有相关内容。

**enum 的内部实现**

《二哥的 Java 进阶之路暗黑版》指出 enum 的字节码结构：

- enum 类隐式继承 `java.lang.Enum`
- 每个常量是 `public static final` 的 enum 实例
- 构造器是 `private`，由编译器生成的静态初始化块调用
- 有一个 `values()` 方法返回所有常量的数组副本（每次调用返回新数组）

因此 enum 常量**天然是单例**且**线程安全**（JVM 保证静态初始化只执行一次）。

**enum 实现抽象方法的技巧**

《Effective Java》与《二哥的 Java 进阶之路》都提到这个 enum 的独特能力——常量实现抽象方法：

```java
enum Operation {
    PLUS {
        @Override int apply(int a, int b) { return a + b; }
    },
    MINUS {
        @Override int apply(int a, int b) { return a - b; }
    };
    abstract int apply(int a, int b);
}
```

这比常量类强得多：常量类无法给不同常量不同的行为（除非配合内部类或用 Map 分发）。

**EnumMap 与 EnumSet 的性能**

《二哥的 Java 进阶之路暗黑版》指出这是 enum 的另一个实用优势：

| 场景 | 推荐 | 原因 |
| --- | --- | --- |
| key 是 enum | `EnumMap` | 内部用数组 + 二分查找，不用哈希 |
| 元素是 enum | `EnumSet` | 位向量实现，极致省内存 |

`EnumMap` 内部就是一个 `Object[]`，key 通过 `ordinal()` 定位，所以查找是数组下标而非哈希。

**《Effective Java》第 22 条：用枚举代替常量**

书中第 22 条列举了 enum 相对 `static final` 的优势：

1. 类型安全——只能传入 enum 类型的值
2. 每个常量都有单例身份——`==` 比较可靠
3. 可以为每个常量附加数据与行为
4. 天然支持 switch（`static final` 也支持，但 enum 更类型安全）

**enum 的具体类不能有子类**

《二哥的 Java 进阶之路》指出：enum 类隐式 final，不能被继承。若要针对不同常量有不同的行为，使用「常量特定类主体」（constant-specific class body）而不是继承。

**record 的编译器生成内容**

《二哥修订版《30天速通Java》暗黑版》与《二哥的 Java 进阶之路》介绍 record 时列出编译器自动生成的部分：

- `private final` 的组件字段
- 规范构造器（canonical constructor）
- 每个组件的访问器（`x()`，**不是** `getX()`）
- `equals` / `hashCode`（基于所有组件）
- `toString`（形如 `Point[x=1, y=2]`）

**紧凑构造器**是校验与归一化的入口：

```java
record User(String name, String email) {
    User {
        name = name.trim();          // 归一化
        if (email == null || !email.contains("@"))
            throw new IllegalArgumentException("invalid email");
    }
}
```

注意紧凑构造器里对参数的**重新赋值**会自动写回字段。

**record 是名义 final 但可实现接口**

《二哥的 Java 进阶之路暗黑版》强调：

```java
record Point(int x, int y) implements Comparable<Point> {
    @Override public int compareTo(Point o) { return Integer.compare(x, o.x); }
}
```

record 不能 `extends`（已隐式继承 `java.lang.Record`），但可以实现任意数量的接口——这让它适合做数据传输对象（DTO）。

**record 与可变性的取舍**

《Effective Java》第 16/17 条的精神在 record 上依然适用：record 组件若是可变对象，仍需防御性拷贝：

```java
record Order(List<Item> items) {
    Order {
        items = List.copyOf(items);   // 防御性拷贝
    }
}
```

**switch 模式匹配的演进**

《二哥修订版《30天速通Java》暗黑版》提到 switch 的表达能力演进：

- Java 7：switch 只支持 int/short/byte/char/enum，case 标签必须是常量
- Java 14：引入 switch 表达式（`yield` 返回值）
- Java 16：引入 record 模式匹配（`case Point(int x, int y)`）
- Java 17：引入 sealed 类型，switch 可以做**穷尽性检查**
- Java 21：模式匹配 switch 正式

sealed 的意义正在于此：编译器知道所有可能的子类型后，`switch` 不需要 `default` 分支，**新增一个子类而漏改 switch 时编译器会报错**。

## 实战提示

**enum 的实际用法**：

```java
// 带状态与行为的 enum，比一堆常量类优雅
enum OrderStatus {
    CREATED {  boolean canTransitionTo(OrderStatus next) { return next != CREATED; } },
    PAID    {  boolean canTransitionTo(OrderStatus next) { return next == SHIPPED; } },
    SHIPPED {  boolean canTransitionTo(OrderStatus next) { return false; } };

    public abstract boolean canTransitionTo(OrderStatus next);
}
```

**record 作为 DTO 的现代写法**：

```java
// 之前需要 40 行样板代码，现在 1 行
record CreateUserRequest(String name, String email, int age) { }

// Spring Boot 3 + Jackson 原生支持 record 反序列化
@PostMapping("/users")
User create(@RequestBody CreateUserRequest req) { ... }
```

**sealed 的实用场景**：领域模型的状态机、AST 节点、支付方式等**类型集合已知且会演进**的场景。

```java
sealed interface PaymentResult permits Success, Failure, Pending {}
record Success(String orderId, BigDecimal amount) implements PaymentResult {}
record Failure(String code, String message) implements PaymentResult {}
record Pending(String orderId) implements PaymentResult {}

// 编译器保证穷尽，无需 default
String render(PaymentResult r) {
    return switch (r) {
        case Success s -> "成功：" + s.orderId();
        case Failure f -> "失败：" + f.message();
        case Pending p -> "处理中：" + p.orderId();
    };
}
```

**注意 record 的两个限制**：不能有额外的**实例**字段（只能有静态的）；不能继承其它类。需要额外状态时，得用普通 final 类或把状态放进组件里。
' WHERE slug = 'enum-and-record';

-- inner-class-and-lambda
UPDATE lesson SET content = '## 本节要点
四种内部类与函数式接口。

## 核心概念
- 四种内部类的访问权限差异
- 匿名内部类的快速写法
- Lambda 与函数式接口

## 关键代码
```
class Outer {
    private int count = 0;

    class Inner {                      // 成员内部类，可访问外部字段
        void add() { count++; }
    }

    static class StaticInner {}        // 静态内部类，不依赖外部实例

    void run() {
        Runnable r = () -> System.out.println("Lambda 表达式");  // Lambda
        new Thread(new Runnable() {   // 匿名内部类
            @Override public void run() { System.out.println("匿名"); }
        }).start();
    }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区
- [''在静态方法里创建非静态内部类对象，失去外部类实例'', ''Lambda 捕获的局部变量必须是 final 或事实上不可变'']

## 动手练习
用 Lambda 写一个 Comparator，对一组字符串按长度再按字典序排序，对比匿名内部类写法。
' WHERE slug = 'inner-class-and-lambda';

-- exception-handling
UPDATE lesson SET content = '## 本节要点

Java 异常体系分两大类：**受检异常**（checked，编译器强制捕获）与**非受检异常**（unchecked，RuntimeException 及其子类）。设计原则是「能用受检就用受检，能用非受检就用非受检」——**受检异常用于可预期的、由调用方能处理的错误；非受检用于编程错误**。

## 核心概念

- **Throwable** → Error（严重错误，通常不处理）/ Exception（可预期错误）。
- **受检异常**：Exception 的非 RuntimeException 子类。编译器要求 catch 或 throws。
- **非受检异常**：RuntimeException 及其子类（NullPointerException、IllegalArgumentException、IllegalStateException、ArithmeticException、ClassCastException…）。
- **Error**：StackOverflowError、OutOfMemoryError、NoClassDefFoundError。JVM 层面问题，不该 catch。
- **异常链（cause）**：Throwable 的 `cause` 字段，包装异常时保留原始异常。
- **try-with-resources**（JDK 7+）：自动关闭资源，**且被抑制的异常会被保留**（addSuppressed）。
- **finally 的执行规则**：正常结束、抛异常、return —— 都会执行 finally。**但 System.exit / 致命错误不会**。
- **try-catch 中 return 的坑**：finally 里的 return 会**吞掉** try 块里的 return 或异常。
- **自定义异常**：继承 RuntimeException（不强制捕获）或 Exception（强制捕获）。
- **异常不能用作控制流**：性能开销（构造异常要填栈帧）。
- **全局异常处理器**：Spring 的 @ControllerAdvice、@RestControllerAdvice。

## 关键代码

```java
// try-with-resources：自动关闭，且保留被抑制的异常
try (BufferedReader br = new BufferedReader(new FileReader("f.txt"));
     Writer w = new BufferedWriter(new FileWriter("out.txt"))) {
    String line;
    while ((line = br.readLine()) != null) w.write(line);
}   // 逆序关闭：w 先关，br 后关

// 异常链：保留原始异常
try {
    parse(input);
} catch (NumberFormatException e) {
    throw new BusinessException("解析失败: " + input, e);   // 传 cause
}

// 自定义异常
class BusinessException extends RuntimeException {
    private final String code;
    public BusinessException(String code, String message, Throwable cause) {
        super(message, cause);
        this.code = code;
    }
    public String getCode() { return code; }
}

// 区分「预期的业务异常」与「编程错误」
if (user == null) throw new IllegalArgumentException("user must not be null");
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- catch (Exception e) 一把梭，把所有异常吞掉
- 在 catch 里只 `e.printStackTrace()` 而不处理也不上抛
- 认为 finally 一定会执行——`System.exit()` 时不会
- 忘记自定义异常要调用 `super(message, cause)`，丢失原始堆栈
- catch (Throwable t) ——连 Error 都吞掉，掩盖致命问题

## 动手练习

实现一个健壮的配置解析器：区分格式错误（受检）与缺失字段（非受检），并保证原始异常信息不丢失。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面试题-03-Java异常面试题》《面渣逆袭 Java 基础篇》《二哥的 Java 进阶之路暗黑版》《Effective+Java+中文第二版》对本节有系统覆盖。

**异常体系与面试高频结论**

《面试题-03-Java异常面试题》开篇即梳理了异常体系：

```
Throwable
├── Error                （严重错误，JVM 层面，不该 catch）
│   ├── OutOfMemoryError
│   ├── StackOverflowError
│   └── NoClassDefFoundError
└── Exception
    ├── RuntimeException （非受检，编译器不强制）
    │   ├── NullPointerException
    │   ├── IllegalArgumentException
    │   ├── IllegalStateException
    │   ├── IndexOutOfBoundsException
    │   └── ArithmeticException
    └── 其他             （受检，编译器强制 catch/throws）
        ├── IOException
        ├── SQLException
        └── ClassNotFoundException
```

**《面渣逆袭 Java 基础篇》给出的选型原则**：

- **受检异常**：异常发生原因可以由调用方处理，且不处理就无法继续 —— 如 IO 失败
- **非受检异常**：程序逻辑错误 —— 如 NPE、数组越界

**try-with-resources 的双重优势**

《Effective Java》第 34 条专门讲这个主题，给出两个理由：

1. **自动关闭资源**，不需要 finally 块
2. **保留被抑制的异常** —— 若 try 块抛异常 A、close() 抛异常 B，A 会被保留，B 作为「被抑制异常」附加到 A 上

```java
// 传统写法：close 抛异常会覆盖原始异常
try (Resource r = open()) {
    r.read();       // 抛异常 A
}                   // close() 抛异常 B → A 被丢失！

// try-with-resources：A 保留，B 成为 suppressed
try (Resource r = open()) {
    r.read();
} catch (Exception e) {
    e.getSuppressed();   // 能拿到 B
}
```

**finally 的执行时机**

《二哥的 Java 进阶之路暗黑版》与《面渣逆袭 Java 基础篇》都强调：

- finally 在方法正常结束、抛异常、return 三种情况下**都会执行**
- **唯一不执行的情况是 JVM 退出**（`System.exit()`）或线程被强制终止
- finally 中的 return 会**吞掉** try 中的 return 或异常——这是经典 bug

```java
// 错误：try 中的 return 被 finally 覆盖
int f() {
    try { return 1; }
    finally { return 2; }   // 永远返回 2
}
```

**异常不能用于控制流**

《Effective Java》第 66 条指出：用异常做正常的控制流是性能反模式。构造异常需要**填充整个调用栈的栈帧**，代价是普通 return 的上百倍。书中建议用返回特殊值或 Optional 表达「预期内的失败」。

**自定义异常的设计**

《二哥的 Java 进阶之路暗黑版》指出自定义异常的三条实践：

1. **总是调用 `super(message, cause)`** ——否则原始异常堆栈丢失
2. **区分受检与非受检**：业务异常通常继承 RuntimeException（避免层层 throws 的样板代码）
3. **不要用异常控制流程**，不要捕获后静默吞掉

**Spring 的全局异常处理**

知识库中《深入浅出Java+23种设计模式》与《面渣逆袭 Spring 篇》覆盖了 Spring 的异常体系。核心注解：

```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusiness(BusinessException e) {
        return ResponseEntity.status(400).body(ApiResponse.fail(e.getCode(), e.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleOther(Exception e) {
        log.error("未预期异常", e);       // 必须记日志
        return ResponseEntity.status(500).body(ApiResponse.fail("INTERNAL_ERROR", "系统繁忙"));
    }
}
```

《面渣逆袭 Spring 篇》强调「统一异常处理的三个好处」：统一返回格式、避免每个 Controller 写 try-catch、集中记录日志。

**《Effective Java》第 47/48 条：不要忽略异常**

- 第 47 条：不要忽略异常——空 catch 块会掩盖问题
- 第 48 条：不要捕获 Throwable 或 Error

## 实战提示

**异常处理的三个层次**：

| 层次 | 做什么 |
| --- | --- |
| 边界层（Controller/消息消费者） | 兜底 + 记日志 + 转成统一响应 |
| 业务层 | 抛业务异常，附带错误码与上下文 |
| 工具层 | 只处理能恢复的异常，其余上抛 |

**判断该不该 catch**：

```
我能在这里修复它吗？      → 不能 → 上抛
调用方能处理它吗？        → 能 → 受检异常 + 文档说明
这是编程错误（bug）？     → 是 → 非受检异常，让它炸出来
```

**性能提示**：热点路径上不要用异常做控制流。`try-catch` 本身几乎无开销（JIT 会优化掉无异常的路径），**真正的开销在于构造异常对象**——它要填充栈帧。

**日志的正确写法**：

```java
// 错误：字符串被无条件拼接，即使不抛异常也有开销
log.debug("处理订单 " + orderId + " 金额 " + amount);

// 正确：参数化日志，异常时才格式化
log.debug("处理订单 {} 金额 {}", orderId, amount);

// 错误：丢失堆栈
log.error("出错了: " + e.getMessage());

// 正确：传 Throwable 本身
log.error("处理订单失败", e);
```
' WHERE slug = 'exception-handling';

-- generics-type-erasure
UPDATE lesson SET content = '## 本节要点

Java 的泛型是**编译期**特性：编译器做类型检查，运行时被**擦除**（erasure）成原始类型。这解释了泛型数组不能直接创建、无法用 `instanceof` 判断泛型类型等问题。

## 核心概念

- **泛型**：类型参数化，把「类型的不确定性」推迟到编译期。
- **类型擦除**：编译后泛型信息被擦除成原始类型（无参或 Object），编译器在需要处插入**强制转换**。
- **桥方法（Bridge Method）**：为保证多态（重写泛型方法）而由编译器生成的合成方法。
- **泛型数组**：不能 `new T[]`，因为运行时不知道 T 的实际类型（无具体化）。可用 `Class<T>` 拿到再 new。
- **堆污染（Heap Pollution）**：泛型类型与实际类型不一致的状态（如通过原始类型或未检查转换产生）。
- **通配符**：上界 `? extends T`（只读，协变）、下界 `? super T`（写，反协变）、无界 `?`（只读任何类型）。
- **PECS 原则**：Producer Extends, Consumer Super。生产用 `? extends`，消费用 `? super`。
- **无界通配符 `?`**：表示「某个未知类型」，只能作为参数使用，不能作为字段/返回值。
- **泛型方法的类型推断**：JDK 7 引入菱形 `<>`，JDK 8 引入目标类型推断。
- **堆污染的防护**：`@SafeVarargs`、`@SuppressWarnings("unchecked")`。

## 关键代码

```java
// 泛型类 + 泛型方法
class Box<T> {
    private T content;
    void set(T c) { this.content = c; }
    T get() { return content; }
}

// 泛型方法：自己的类型参数
static <T> T firstNonNull(List<T> list, T defaultValue) {
    return list.isEmpty() ? defaultValue : list.get(0);
}

// PECS：生产者用 extends，消费者用 super
static double sum(List<? extends Number> nums) {           // 生产者：只读
    double s = 0;
    for (Number n : nums) s += n.doubleValue();
    return s;
}
static void fill(List<? super Integer> list) {              // 消费者：可写
    list.add(1);
    list.add(2);
}

// 泛型数组：用 Class<T> 拿到运行时类型
static <T> T[] newArray(Class<T> type, int size) {
    @SuppressWarnings("unchecked")
    T[] arr = (T[]) java.lang.reflect.Array.newInstance(type, size);
    return arr;
}

// 桥方法的存在（编译器自动生成）
interface Comparator<T> { int compare(T a, T b); }
class StringComparator implements Comparator<String> {
    public int compare(String a, String b) { return a.compareTo(b); }
    // 编译器生成：public int compare(Object a, Object b) { return compare((String)a, (String)b); }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为泛型在运行时还保留类型信息——被擦除了，`list.getClass()` 得到的是 `ArrayList.class`
- 直接 `new T[]` 或 `new List<String>[]`——编译报错
- 用 `instanceof List<String>` 判断泛型类型——非法，只能判断原始类型
- 混淆 `List<?>` 与 `List<Object>`——前者是只读的未知类型，后者是可写的具体类型
- PECS 用反：消费方用 `? extends` 会导致无法写入

## 动手练习

实现一个泛型的 `Result<T>` 容器（成功值或错误），并用 PECS 写一个能接收任意数字列表求和的方法。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《二哥的 Java 进阶之路暗黑版》《深入理解高并发编程（第 2 版）》《面渣逆袭 Java 基础篇》《面试题-01-Java基础知识面试题》对本节有相关论述。

**类型擦除的规则**

《二哥的 Java 进阶之路暗黑版》与《深入理解 JVM 核心技术》都覆盖了擦除的细节：

擦除规则：
- 若类型参数无界 → 擦除为 `Object`
- 若有上界（如 `T extends Number`）→ 擦除为**上界类型**（`Number`）
- 无具体化的类型变量 → 擦除为其声明处的上界

因此：

```java
class Box<T extends Number> { }
// 运行时等价于 class Box { ... }，字段类型是 Number
```

**桥方法的作用**

《深入理解 JVM 核心技术》与《二哥的 Java 进阶之路》指出，编译器在泛型类中会生成**桥方法**（bridge method）以保持多态的正确性：

```java
class StringComparator implements Comparator<String> {
    public int compare(String a, String b) { ... }
    // 编译器生成桥方法：
    // public int compare(Object a, Object b) {
    //     return compare((String) a, (String) b);
    // }
}
```

没有桥方法，编译器在调用 `Comparator.compare(Object, Object)` 时就无法正确分派。可以用 `javap -p` 看到 `ACC_BRIDGE` 与 `ACC_SYNTHETIC` 标记。

**泛型数组为什么不能直接创建**

《面渣逆袭 Java 基础篇》与《二哥的 Java 进阶之路》给出解释：数组在运行时必须知道**具体类型**才能做类型检查与内存布局。`new T[]` 中的 T 在运行时已被擦除，JVM 无从得知该分配什么类型的数组。

两种解法：

```java
// 1. 传入 Class<T> 引用
static <T> T[] create(Class<T> clazz, int size) {
    return (T[]) Array.newInstance(clazz, size);
}

// 2. 传入已有数组作为模板（数组协变，可直接强转）
static <T> T[] create(T[] template, int size) {
    return (T[]) Array.newInstance(template.getClass().getComponentType(), size);
}
```

**堆污染与 unchecked 警告**

《面试题-01-Java基础知识面试题》与《二哥的 Java 进阶之路》都解释了堆污染：

```java
// 堆污染示例
List<String> list = new ArrayList<Object>();   // unchecked 警告
list.add("hello");
Object o = list.get(0);
String s = (String) o;    // 运行时可能 ClassCastException
```

规避手段：
- 尽量用泛型 API 而非原始类型
- 必须强转时用 `@SuppressWarnings("unchecked")` 明确标注意图
- 对可变参数用 `@SafeVarargs`（Java 9+ 可用于私有方法）

**PECS 原则的完整表述**

《二哥的 Java 进阶之路暗黑版》把 PECS 讲得很清楚：

- **Producer Extends**：`List<? extends T>` 表示「这个列表里装的东西都是 T 的子类型」，所以**只能读**——读出来当 T 用是安全的
- **Consumer Super**：`List<? super T>` 表示「这个列表能装 T 或 T 的父类型」，所以**可以写** T 进去

经典例子：

```java
// 这个方法只能读 Number，所以用 extends
void process(List<? extends Number> list) {
    Number n = list.get(0);     // 安全
    // list.add(1);             // 编译错误！
}

// 这个方法往里写 Integer，用 super
void fill(List<? super Integer> list) {
    list.add(1);                // 安全
    // Number n = list.get(0);  // 只能读回 Object
}
```

**无界通配符 vs Object**

《面渣逆袭 Java 基础篇》区分了这两个容易混淆的写法：

| | `List<?>` | `List<Object>` |
| --- | --- | --- |
| 含义 | 某个未知类型 | 明确是 Object |
| 能读吗 | 能，只能当 Object 读 | 能，当 Object 读 |
| 能写吗 | 不能（除了 null） | 能 |
| 能作为字段吗 | 不能 | 能 |
| 典型用途 | 方法参数 | 字段 |

**泛型方法的类型推断**

《二哥的 Java 进阶之路暗黑版》提到 JDK 7 与 JDK 8 的推断增强：

```java
// JDK 7：菱形推断
List<String> list = new ArrayList<>();

// JDK 8+：目标类型推断
List<String> list = Collections.emptyList();
Stream.of(1, 2, 3).map(String::valueOf).forEach(System.out::println);
```

**泛型的边界：不能用基本类型**

《Java编程思想第四版》指出泛型不支持基本类型——`List<int>` 非法，必须写 `List<Integer>`。原因是类型擦除后 `int` 要装箱成 `Integer`，编译器会做自动装箱，但会带来装箱开销与可能的 NPE（缓存范围外的 `Integer`）。

## 实战提示

**泛型设计的实用原则**：

1. **只在确实需要的地方用泛型**——过度泛型会让 API 难懂
2. **返回类型用具体类型，参数用通配符**（PECS）
3. **不要用 `List<Object>` 代替 `List<?>`**——前者允许写入，破坏类型安全

**处理 JSON/ORM 的泛型边界**：

```java
// 常见问题：无法在运行时确定 T
class JsonUtils {
    static <T> T fromJson(String json, Class<T> type) {
        return JSON.parseObject(json, type);   // 必须传 Class
    }
    // 无法这样写：static <T> T fromJson(String json) { ... }
}
```

Spring 的 `RestTemplate`、`@RequestBody` 等都依赖 `Class<T>` 或 `ParameterizedTypeReference` 来解决这个限制：

```java
// 需要带泛型的参数化类型时
ParameterizedTypeReference<List<Order>> ref =
    new ParameterizedTypeReference<>() {};
```

**泛型与反射的配合**：`TypeToken`（Gson）/ `TypeReference`（Jackson）都是这个模式的应用。

**一个实用建议**：对外暴露的 API 用具体泛型（`Result<User>`），内部工具类用通配符（`void copy(List<? super T> from, List<? extends T> to)`），这样调用方最自由。
' WHERE slug = 'generics-type-erasure';

-- reflection-annotation
UPDATE lesson SET content = '## 本节要点

反射让程序在**运行时**检查和操作类型：读注解、创建实例、调用方法、访问字段。注解是给**编译器/JVM**看的元数据，`@Retention` 决定它的生命周期，运行时注解配合反射才能被读取。

## 核心概念

- **Class 对象**：每个类在 JVM 中都有唯一的 Class 实例，持有该类的全部元信息。
- **反射 API**：`Class`、`Method`、`Field`、`Constructor`、`Modifier`。
- **注解的 Retention**：`SOURCE`（仅源码，编译丢弃）/ `CLASS`（编译进 class 文件，运行时不可读）/ `RUNTIME`（运行时可读，最常用）。
- **注解的 Target**：`TYPE`、`METHOD`、`FIELD`、`PARAMETER` 等，限定可标注位置。
- **@Inherited**：允许子类继承父类的注解（只对类有效）。
- **重复注解**：`@Repeatable`（Java 8+）。
- **元注解**：标注注解的注解（`@Retention`、`@Target`、`@Documented`、`@Inherited`）。
- **动态代理**：`Proxy.newProxyInstance` 基于接口生成代理类，Spring AOP 的底层。
- **性能代价**：反射比直接调用慢（需装箱、访问检查），但 JIT 会对热点反射做优化。
- **setAccessible(true)**：突破访问控制，JDK 9+ 对 JDK 内部模块有强限制。
- **MethodHandle**（Java 7+）：比反射更快，是 JDK 内部（如 lambda）的实现基础。

## 关键代码

```java
// 定义运行时注解
@Retention(RetentionPolicy.RUNTIME)     // 运行时可读
@Target({ElementType.METHOD, ElementType.TYPE})
@interface MyAnnotation {
    String value() default "";
    int priority() default 0;
}

// 读取注解
Method method = MyService.class.getMethod("doWork");
if (method.isAnnotationPresent(MyAnnotation.class)) {
    MyAnnotation ann = method.getAnnotation(MyAnnotation.class);
    System.out.println(ann.value() + " / " + ann.priority());
}

// 反射创建实例与调用方法
Class<?> clazz = Class.forName("com.example.Foo");
Object obj = clazz.getDeclaredConstructor().newInstance();
Method m = clazz.getMethod("hello", String.class);
Object result = m.invoke(obj, "world");

// 访问私有字段
Field field = Foo.class.getDeclaredField("secret");
field.setAccessible(true);
System.out.println(field.get(obj));

// 动态代理（Spring AOP 基础）
interface Service { String doWork(String arg); }
Service proxy = (Service) Proxy.newProxyInstance(
        Service.class.getClassLoader(),
        new Class<?>[]{Service.class},
        (p, method, args) -> "代理前拦截 -> " + method.invoke(p, args));
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 忘了 `@Retention(RetentionPolicy.RUNTIME)`，注解编译后就没了，运行时读不到
- 认为 `@Inherited` 对方法注解有效——只对类注解有效
- 在反射调用时忘了处理 `InvocationTargetException`——真实异常被包装了
- 滥用 `setAccessible(true)` 突破封装，JDK 9+ 模块系统下会失败
- 用反射做本可以静态调用的热路径，性能损失明显

## 动手练习

实现一个极简的「注解 + 反射」依赖注入：自定义 `@Inject` 注解，扫描字段并自动赋值。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《SpringIOC核心技术-冰河》《Spring源码深度解析（第 2 版）》《深入浅出Java+23种设计模式》《二哥的 Java 进阶之路暗黑版》对本节机制有原理性支撑。

**注解的 Retention 与生命周期**

《二哥的 Java 进阶之路暗黑版》指出注解的三种保留策略决定了它能活多久：

| Retention | 生命周期 | 典型用途 |
| --- | --- | --- |
| `SOURCE` | 只在源码，编译即丢弃 |  Lombok、Checkstyle 注解 |
| `CLASS` | 进 class 文件，运行时不可读（默认） | 字节码增强工具 |
| `RUNTIME` | 保留到运行，**反射可读** | Spring 的 `@Component`/`@Transactional`、JUnit 的 `@Test` |

**默认是 `CLASS`**——这是最常见的踩坑点：写了注解却读不到，多半是忘了显式声明 `RUNTIME`。

**Spring 的注解驱动本质**

《SpringIOC核心技术-冰河》系统讲解了 Spring 的 IOC 实现原理，核心链路正是「注解 + 反射」：

```
@Component 扫描 → 解析出 bean 定义 → 实例化（反射调用构造器）
    → 依赖注入（反射设置字段 / 调用 setter）
    → AOP 代理（动态代理 / 字节码增强）
```

知识库中《Spring 源码深度解析（第 2 版）》与《SpringIOC核心技术》都指出：Spring 的注解本身只是**元数据**，真正干活的是 `AnnotationBeanNameGenerator`、`AutowiredAnnotationBeanPostProcessor` 这些后置处理器——它们通过反射读取注解并执行相应操作。

这正是理解反射价值的最佳案例：**注解本身什么都不做，是反射让它产生效果**。

**动态代理 JDK 与 CGLIB**

《深入浅出Java+23种设计模式》与《SpringIOC核心技术》都对比了两种 AOP 实现：

| | JDK 动态代理 | CGLIB（字节码增强） |
| --- | --- | --- |
| 前提 | 必须有**接口** | 无需接口（生成子类） |
| 实现 | `Proxy.newProxyInstance` | ASM / ByteBuddy 生成字节码 |
| 局限 | 只能代理接口方法 | 不能代理 final 类/方法 |

Spring Boot 2.x 之后默认用 CGLIB，因为 Spring 6 / Boot 3 起不再强制要求实现接口。

**代理模式在《深入浅出Java+23种设计模式》中的位置**

这本书把代理模式分为三类：

1. **静态代理**：编译期确定代理类，代码冗余
2. **JDK 动态代理**：运行期基于接口生成 `Proxy` 子类
3. **CGLIB 动态代理**：运行期基于类生成子类

《SpringIOC核心技术-冰河》特别指出 JDK 动态代理的调用链：

```java
// Proxy 内部持有 InvocationHandler
Object result = method.invoke(this, args);   // 转调 handler.invoke()
// handler 里再反射调用真实对象的方法
```

**MethodHandle 与反射的对比**

《二哥的 Java 进阶之路暗黑版》提到 JDK 7 引入的 `MethodHandle`：

- 反射：Method 对象在运行时**查找**得到，有访问检查
- MethodHandle：可以**提前绑定**（`bindTo`），执行时无查找开销

JDK 内部的 lambda 实现就基于 `LambdaMetafactory` + `MethodHandle`，这解释了为什么 lambda 比匿名内部类更省资源。

**反射的性能真相**

《二哥的 Java 进阶之路暗黑版》与《深入浅出Java+23种设计模式》都指出：现代 JVM 对反射做了大量优化（JDK 18+ 的 `MethodHandle` 反射、JDK 21+ 的 hidden classes），热点反射调用的性能差距已大幅缩小。但仍有开销：

- 参数装箱/拆箱
- 每次调用的访问权限检查
- 无法被 JIT 完全内联

结论：**非热点路径用反射无妨，热路径（如每次请求都调）应缓存 `Method` 对象或改用接口/lambda**。

**setAccessible 的限制**

《二哥的 Java 进阶之路暗黑版》指出 JDK 9+ 引入模块系统后：

- `setAccessible(true)` 对**本模块**与**开放模块**有效
- 对 JDK 内部类（如 `java.lang`）会抛 `InaccessibleObjectException`
- 需要 `--add-opens java.base/java.lang=ALL-UNNAMED` 才能访问

这也是 Spring 在 JDK 17+ 需要 `--add-opens` 参数的原因之一。

## 实战提示

**自定义注解的完整模板**：

```java
// 定义
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.FIELD)
@Documented
public @interface Inject {
    boolean required() default true;
}

// 处理
class Injector {
    static void inject(Object target) throws Exception {
        for (Field field : target.getClass().getDeclaredFields()) {
            if (field.isAnnotationPresent(Inject.class)) {
                field.setAccessible(true);
                field.set(target, createBean(field.getType()));
            }
        }
    }
}
```

**读不到注解时的排查顺序**：

1. `@Retention` 是 `RUNTIME` 吗？（最常见）
2. `@Target` 包含目标位置吗？（比如只标了 METHOD 却标在字段上）
3. 注解在**运行时**被保留了吗？（打包插件可能过滤）
4. 是不是代理类导致 `getAnnotation` 拿不到？（用 `AopUtils.getTargetClass` 或 `AnnotationUtils`）

**反射的正确异常处理**：

```java
try {
    method.invoke(obj, args);
} catch (InvocationTargetException e) {
    // 真实异常在 getCause() 里
    throw new BusinessException("调用失败", e.getCause());
} catch (IllegalAccessException e) {
    throw new IllegalStateException("访问权限不足", e);
}
```

**缓存反射结果**：

```java
// 反射结果应当缓存，不要每次都查
private static final Map<Method, MethodHandle> HANDLE_CACHE = new ConcurrentHashMap<>();

// 或者更简单：把反射得到的对象缓存到字段
private final Method cachedMethod = ...;
```

**什么时候该用反射 / 什么时候不该**：

| 场景 | 选择 |
| --- | --- |
| 框架解耦（Spring、MyBatis、JUnit） | 反射 |
| 读取运行时配置/注解 | 反射 |
| 需要动态替换实现 | 动态代理 |
| 业务代码里频繁调用的方法 | 直接调用或用接口 + lambda |
| 编译期就能确定的东西 | 不用反射 |
' WHERE slug = 'reflection-annotation';

-- project-grade-system
UPDATE lesson SET content = '## 本节要点
综合运用 OOP 思想完成一个完整小项目。

## 核心概念
- 需求到类设计的推导过程
- 面向接口编程的收益
- 异常处理在业务层的落点

## 关键代码
```
// 面向接口：换存储实现不影响业务层
interface StudentDao {
    void save(Student s);
    Student findById(long id);
}

class MemoryStudentDao implements StudentDao { /* 内存实现 */ }
// 业务层只依赖接口，将来换成 MySQL 实现无需改业务代码
class GradeService {
    private final StudentDao dao;
    GradeService(StudentDao dao) { this.dao = dao; }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区
- [''把 StudentDao 实现类写死，替换数据库时改动面扩散到整个系统'', ''业务层直接写 SQL，让 DAO 层形同虚设'']

## 动手练习
先用内存版 StudentDao 实现成绩管理，再实现一个基于 Map 的版本，两者可互换使用。
' WHERE slug = 'project-grade-system';

-- collection-overview
UPDATE lesson SET content = '## 本节要点

Java 集合框架分三大分支：**List**（有序可重复、有索引）、**Set**（不可重复）、**Map**（键值对，key 唯一）。所有分支的根都是 `Collection`（Map 不在其下），实现类最终都实现了 `Iterable`，从而支持 for-each。

## 核心概念

- **Collection 接口**：List / Set / Queue / Deque 的父接口，定义了 size、isEmpty、contains、add、remove、iterator、stream 等通用操作。
- **List**：有序、可重复、有索引。三个子接口：ArrayList（数组）、LinkedList（双向链表）、Vector/Stack（同步版，遗留）。
- **Set**：不可重复。HashSet（哈希）、LinkedHashSet（哈希+插入序）、TreeSet（红黑树，有序，支持范围查询）。
- **Map**：key 唯一。HashMap、LinkedHashMap（维护插入序或访问序）、TreeMap（红黑树，key 有序）、Hashtable（遗留）、ConcurrentHashMap。
- **Queue / Deque**：Queue 是队列（FIFO），Deque 是双端队列（可当栈用），ArrayDeque 是主力实现。
- **Iterable**：只有实现了 Iterable 才能被 for-each 遍历（增强 for 实际编译成 Iterator 循环）。
- **Collections 工具类**：unmodifiableList、singletonList、shuffle、reverse 等包装与算法。
- **选择依据**：看是否需要顺序、是否需要去重、是否需要按键查找、数据规模与读写比。

## 关键代码

```java
List<String> list = new ArrayList<>();   // 有序、可重复、可按索引访问
Set<String> set = new HashSet<>();        // 不可重复、查询快
Map<K, V> map = new HashMap<>();          // 键值对，key 不可重复

// 选型口诀：看是否需要重复、是否需要按键查找、是否需要顺序

// Queue 与 Deque
Queue<String> q = new ArrayDeque<>();     // FIFO
Deque<String> d = new ArrayDeque<>();     // 双端，可 push/pop 当栈用

// 不可变集合
List<String> fixed = Collections.unmodifiableList(list);
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 查完接口就随意选实现类，不看访问模式
- 认为 Set 一定比 List 快，忽略数据规模与哈希质量
- 认为 `Collection` 是所有集合的父接口——`Map` 不继承它
- 用 `Arrays.asList()` 的结果去 `add`/`remove`，它返回的是固定长度视图

## 动手练习

把一组字符串分别存入 List、Set、Map，统计去重前后数量与查找耗时。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭 Java 集合框架篇》《面试题-02-Java集合容器面试题》《Java编程思想第四版》《二哥的 Java 进阶之路》对本节覆盖完整。

**List / Set / Map 的三大分支定位**

《面渣逆袭 Java 集合框架篇》把 Java 集合分为三类：

| | 有序 | 可重复 | 可按索引 | 键值对 |
| --- | --- | --- | --- | --- |
| List | [OK] | [OK] | [OK] | [X] |
| Set | 部分（LinkedHashSet/TreeSet） | [X] | [X] | [X] |
| Map | 部分（LinkedHashMap/TreeMap） | key 唯一 | [X] | [OK] |

**为什么要有 Iterable**

《二哥的 Java 进阶之路》与《Java编程思想第四版》都强调：增强 for 循环是编译器提供的语法糖，编译后等价于 Iterator 循环：

```java
for (String s : list) { ... }
// 等价于
Iterator<String> it = list.iterator();
while (it.hasNext()) { String s = it.next(); ... }
```

所以**任何自定义类只要实现 `Iterable`**，就能享受 for-each 与 Stream API 的便利——这是 `Iterable` 存在的根本意义。

**Map 为什么不是 Collection 的子接口**

《面渣逆袭 Java 集合框架篇》指出，`Collection` 表达的是「一组元素」，而 Map 表达的是「键值对的映射」，语义不同。历史上 Java 团队承认这是设计失误（Map 没有 `add` 而有 `put`），但改动代价太大，只能保留。

**Queue 与 Deque 的实现选择**

《Java编程思想第四版》第 11 章「集合"》详细对比了各实现的性能：

| 实现 | 结构 | 允许 null | 迭代顺序 | 随机访问 |
| --- | --- | --- | --- | --- |
| ArrayList | 数组 | 允许 | 插入序 | O(1) |
| LinkedList | 双向链表 | 允许 | 插入序 | O(n) |
| HashSet | 哈希表 | 允许**一个** null | 无序 | O(1) |
| TreeSet | 红黑树 | 不允许 | 排序序 | O(log n) |
| ArrayDeque | 循环数组 | 不允许 | FIFO | O(1) |
| PriorityQueue | 二叉堆 | 不允许 | 优先级序 | O(1) |

**关键结论：优先用 ArrayList 而非 LinkedList。** 大多数人从教材上学到"LinkedList 插入删除快"，但实际上：

- LinkedList 的每次插入/删除都要先定位到节点，O(n)
- ArrayList 的尾部添加是**均摊 O(1)**，且**缓存友好**（连续内存）
- 真正需要频繁在中间插入删除的场景极少，且那种场景通常用 `LinkedList` 也未必更好

**HashMap 与 TreeMap 的选择**

《面渣逆袭 Java 集合框架篇》给出决策依据：只需要 key 无序且快速查找 → HashMap；需要 key 有序或范围查询（`subMap`、`headMap`）→ TreeMap；需要维护插入顺序或 LRU → LinkedHashMap。

**Collections 工具类的常用方法**

《Java编程思想第四版》介绍了 `Collections` 的三类方法：

```java
Collections.sort(list);                       // 排序
Collections.unmodifiableList(list);            // 不可变视图（不是拷贝，仍受原集合影响）
Collections.emptyList();                       // 共享的空集合实例
Collections.shuffle(list, new Random(42));     // 洗牌（固定种子可复现）
Collections.frequency(list, "a");              // 统计出现次数
```

**注意 `unmodifiableList` 返回的是视图而非拷贝**——原集合变化会影响它，要真正隔离需 `new ArrayList<>(...)`。

**Queue 的阻塞与非阻塞**

《Java编程思想第四版》区分了 `Queue`（java.util）与 `BlockingQueue`（java.util.concurrent）：后者额外提供 `put`/`take`（阻塞）与 `offer`/`poll`（超时版本），是线程池与生产者-消费者模式的基础。

## 实战提示

**常见场景选型表**：

| 需求 | 选择 |
| --- | --- |
| 元素有序、可重复、按索引访问 | `ArrayList` |
| 元素去重 | `HashSet` |
| 去重且保持插入顺序 | `LinkedHashSet` |
| key 有序、支持范围查询 | `TreeMap` |
| 按 key 查找且要线程安全 | `ConcurrentHashMap` |
| 实现 LRU 缓存 | `LinkedHashMap`（accessOrder=true） |
| 队列 / 栈 | `ArrayDeque`（不要用 `Stack` 和 `LinkedList`） |

**性能上的两个常见误判**：

1. **小规模数据用 LinkedList 更慢**——链表的指针跳转与对象头开销在大数据量下才体现优势
2. **TreeMap 比 HashMap 慢**——红黑树每次操作多 O(log n) 的指针跳转，只有需要有序时才值得

**遍历删除的正确写法**：

```java
// 需要按条件删除时，用 removeIf（内部用迭代器，无 CME 风险）
list.removeIf(s -> s.isEmpty());

// 或用迭代器自身的 remove()
Iterator<String> it = list.iterator();
while (it.hasNext()) {
    if (it.next().isEmpty()) it.remove();
}
```
' WHERE slug = 'collection-overview';

-- arraylist-source
UPDATE lesson SET content = '## 本节要点

ArrayList 底层是**动态数组**。`add` 是均摊 O(1)——平时尾插 O(1)，偶尔扩容时拷贝一次 O(n)。扩容策略在 JDK 8 之后改为 **1.5 倍**（`oldCapacity + (oldCapacity >> 1)`）。

## 核心概念

- **elementData**：底层数组，JDK 8 起为 `Object[]`，**延迟初始化**（首次 add 才 new，默认空数组共享）。
- **size**：实际元素个数（不是数组长度）。
- **DEFAULT_CAPACITY = 10**：默认初始容量。
- **扩容倍数**：JDK 7 及以前 1.5 倍，JDK 8 起 `oldCap + (oldCap >> 1)` 即 1.5 倍，**过大的数组浪费内存**，小于 1.5 倍则扩容过于频繁。
- **modCount**：记录结构性修改次数，是 fail-fast 机制的基础（见迭代器课时）。
- **Arrays.copyOf**：扩容时拷贝旧数组到新数组。
- **RandomAccess 接口**：ArrayList 实现它，标记支持快速随机访问。
- **ensureCapacity / trimToSize**：手动控制容量。
- **System.arraycopy**：JDK 8+ 扩容用 native 方法，比循环拷贝快。

## 关键代码

```java
// 源码核心逻辑（简化）
public boolean add(E e) {
    ensureCapacity();               // 容量不够就扩容
    elementData[size++] = e;       // 尾部写入，O(1) 均摊
    return true;
}
private void ensureCapacity() {
    if (size == elementData.length)
        elementData = Arrays.copyOf(elementData, size * 2);  // 1.5 倍或 2 倍
}

// size() 只是返回字段，O(1)
public int size() { return size; }
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 ArrayList 插入一定是 O(1)，忽略偶尔扩容时的 O(n)
- 已知容量却用 `Arrays.asList` 创建不可变列表，`add` 直接抛异常
- 以为 `new ArrayList<>(collection)` 会预分配足够容量，实际上只按 `size * 1.5` 估算
- 用 `list.remove(Integer)` 删元素——它是按**下标**删；要删值得用 `remove(Object)` 或 `removeIf`

## 动手练习

预置容量 10 依次 add 30 个元素，用调试器观察 elementData.length 的变化次数。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭 Java 集合框架篇》《面试题-02-Java集合容器面试题》《二哥的 Java 进阶之路》《Java编程思想第四版》对本节覆盖详细。

**为什么扩容是 1.5 倍**

《二哥的 Java 进阶之路》与《面试题-02-Java集合容器面试题》都给出了这个经典分析：

- 扩容 **2 倍**：内存浪费严重（扩容后可用空间可能远超需要），且大数组拷贝成本高
- 扩容 **1.5 倍**：空间与拷贝成本的折中。JDK 8 起用 `oldCap + (oldCap >> 1)` 替代 `oldCap * 1.5`（后者会溢出），结果一致

以 JDK 8 默认容量 10 起步，扩容序列是：10 → 15 → 22 → 33 → 49 → 73 → 109 → 163 → 244 → 366 → 549 → 823 → 1234 → 1851 → 2776 → 4164 → 6246 → 9369 → 14053。

**RandomAccess 标记接口**

《Java编程思想第四版》指出 `RandomAccess` 是一个**标记接口**（marker interface），没有任何方法。`ArrayList` 实现它、`LinkedList` 不实现。作用是让算法代码能区分：

```java
if (list instanceof RandomAccess) {
    for (int i = 0; i < list.size(); i++) list.get(i);   // O(1) 按下标
} else {
    for (Object o : list) { ... }                          // 用迭代器
}
```

《Java编程思想第四版》明确建议：**不要把 LinkedList 当作 ArrayList 的替代品**——虽然接口相同，但把 ArrayList 换成 LinkedList 会让大量代码从 O(1) 退化成 O(n)。

**ArrayList 与 Vector 的区别**

《面试题-02-Java集合容器面试题》对比了历史遗留类：

| | ArrayList | Vector | Stack |
| --- | --- | --- | --- |
| 线程安全 | 否 | 是（方法级 synchronized） | 是（继承 Vector） |
| 扩容 | 1.5 倍 | 2 倍 | 2 倍 |
| 迭代器 | fail-fast | **枚举器，fail-fast 失效** | — |

生产代码里不应再使用 `Vector` 与 `Stack`：前者每次操作都要加锁，后者是遗留的栈实现（现代用 `ArrayDeque`）。

**Arrays.asList 的坑**

《面试题-02》专门提到这个高频陷阱：

```java
List<String> list = Arrays.asList("a", "b");
list.add("c");    // UnsupportedOperationException
list.set(0, "x"); // 可以（set 允许）
```

原因：`Arrays.asList` 返回的是**固定长度**的视图（`Arrays$ArrayList`），底层仍指向原数组。真正可变且独立需：

```java
List<String> list = new ArrayList<>(Arrays.asList("a", "b"));
```

**subList 的视图性质**

《面渣逆袭 Java 集合框架篇》指出 `subList` 返回的也是**视图**，不是拷贝：

```java
List<String> sub = list.subList(0, 3);
sub.clear();          // 会清空原 list 的前 3 个元素！
```

这在生产中是个隐蔽的 bug 来源——对 subList 的任何结构性修改都会反映到原集合。

**序列化机制**

《二哥的 Java 进阶之路》提到 ArrayList 的 `writeObject` 做了定制：它不直接用默认序列化，而是逐个写入元素并记录 size，元素本身为 null 时写 -1 占位。这让反序列化时能精确还原 size 而不需要试探。

## 实战提示

**预置容量**：已知大小时预分配，避免多次扩容与数组拷贝：

```java
List<Order> list = new ArrayList<>(expectedSize * 10 / 9);   // 1.1 倍经验值
```

**遍历性能**：下面三种写法性能差异明显（数据量大时）：

```java
// 1. 索引遍历（ArrayList 最快，LinkedList 最慢）
for (int i = 0; i < list.size(); i++) { process(list.get(i)); }

// 2. 增强 for（编译成迭代器，通用）
for (Order o : list) { process(o); }

// 3. Stream（并行时最快，但有小数据量开销）
list.parallelStream().forEach(this::process);
```

**大列表的删除陷阱**：`remove(int index)` 与 `remove(Object o)` 重载不同——传 `int` 走下标，传 `Integer` 走值比较。用 `removeIf` 最安全，它内部用迭代器且只遍历一次。

**内存优化**：如果元素是 `Byte/Short/Integer/Long/Character/Boolean/Float/Double`，可以改用 `Arrays.asList` 包装成基本类型数组，内存占用能降一半以上（去掉每个对象的引用与对象头开销）。
' WHERE slug = 'arraylist-source';

-- hashmap-red-black-tree
UPDATE lesson SET content = '## 本节要点

HashMap = **数组 + 链表 + 红黑树**。`hash()` 做扰动把冲突降到最低，`putVal` 走「空桶直接放 / 桶内有 key 则覆盖 / 否则挂链表或树化」三条路径。链表长度 ≥ 8 且数组长度 ≥ 64 时转红黑树。

## 核心概念

- **DEFAULT_CAPACITY = 16**：默认初始容量。
- **LOAD_FACTOR = 0.75**：负载因子，元素数 > capacity × 0.75 时扩容。
- **TREEIFY_THRESHOLD = 8**：链表长度达 8 转红黑树。
- **UNTREEIFY_THRESHOLD = 6**：树缩回链表的阈值（留 2 的缓冲避免反复转换）。
- **MIN_TREEIFY_CAPACITY = 64**：数组容量不足 64 时优先扩容而非树化。
- **hash() 扰动函数**：`h ^ (h >>> 16)`，让高 16 位参与低位运算。Java 8 之前是 `h ^ (h >>> 20) ^ (h >>> 12)`，因为 HashMap 用 `h & (n-1)` 取模，只用到了低位。
- **扩容**：容量翻倍为 2 的幂，取模可以用位运算 `& (n-1)` 替代 `%`。
- **红黑树化**：解决链表过长导致的 O(n) 查找，主要对抗恶意哈希碰撞。
- **节点类型**：链表节点 `Node`，树节点 `TreeNode`（多了 parent/left/right/prev）。

## 关键代码

```java
// 核心参数
static final int DEFAULT_CAPACITY = 16;
static final float LOAD_FACTOR = 0.75f;
static final int TREEIFY_THRESHOLD = 8;    // 链表长度 ≥8 转红黑树
static final int UNTREEIFY_THRESHOLD = 6;  // 树缩回链表的阈值

// 为什么阈值是 8：泊松分布下冲突到 8 的概率极低，
// 正常情况链表很短，转树主要是为了对抗恶意构造的哈希碰撞

// 扰动函数：让高位也参与定位
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 HashMap 是绝对线程安全的，并发下会成环导致 CPU 100%
- 只记「冲突转红黑树」却不知道为什么阈值是 8
- 以为 `HashMap` 有序——它完全无序，需要有序用 `LinkedHashMap` 或 `TreeMap`
- 在并发场景直接用 `HashMap`，JDK 7 会成环，JDK 8 虽不死循环但仍会丢数据

## 动手练习

构造一组 key，让 hashCode 只差 1，插入 10 个观察链表是否树化（需包级访问或反射）。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《二哥的 Java 进阶之路暗黑版》《面渣逆袭 Java 集合框架篇》《面试题-02-Java集合容器面试题》《深入理解高并发编程（第 2 版）》对本节覆盖最详尽。

**putVal 的三条路径**

《二哥的 Java 进阶之路》把 `putVal` 的逻辑拆得很清楚：

1. **桶为空** → 直接 new Node 放入（无锁竞争时用 CAS）
2. **桶内首节点 hash 匹配且 key 相同**（`==` 或 `equals`）→ 覆盖 value
3. **否则** → 挂到链表尾部；若链表长度 ≥ 8 且表长 ≥ 64 → 树化；树中同样先查 key 再插入

注意第 3 步在 JDK 8 中要**先判断树化条件中的表长**：表长 < 64 时调用 `resize()` 扩容而非树化，因为小表扩容比树化更划算。

**红黑树的转换条件与过程**

《深入理解高并发编程（第 2 版）》与《二哥的 Java 进阶之路》都给出了「转换为红黑树链表转换为红黑树过程」：

- **树化阈值 8**：为什么不是 7 或 9？泊松分布下，桶中元素达到 8 个的概率约为千万分之六，正常使用几乎不可能触发。树化主要针对**恶意构造的哈希碰撞攻击**——攻击者可以构造出所有 key 落同一桶的数据集，把查找退化成 O(n)。
- **退化阈值 6**：树缩回链表需要 ≥ 6，因为扩容时链表可能被拆成两段（树化会保持相对顺序），若阈值与 8 太近会导致转换抖动。
- **表长门槛 64**：数组小的时候，桶多、每个桶的元素少，扩容比树化成本低。

**扩容机制与高位参与**

《面渣逆袭 Java 集合框架篇》与《二哥的 Java 进阶之路》解释了为什么容量必须是 2 的幂，以及 JDK 8 的优化：

- 容量为 2 的幂 → `hash & (n-1)` 等价于取模，但快得多
- JDK 7 扩容时需要**重算每个 key 的 hash**（`h ^ (h >>> 20) ^ (h >>> 12)`），因为新旧容量取模结果不同
- JDK 8 保留每条链表的**相对顺序**，扩容时按原索引拆成 lo/hi 两条链，无需重算 hash

JDK 8 的 `hash()` 简化成 `h ^ (h >>> 16)`，正是为了让高 16 位参与低位运算，**保证扩容后 hash & (newCap-1) 与 hash & (oldCap-1) 结果相同的那一位**。

**ConcurrentHashMap 的扩容控制**

《深入理解高并发编程（第 2 版）》提到「ConcurrentHashMap 扩容操作控制」——JDK 8 的 ConcurrentHashMap 在扩容时采用**协助扩容**机制：某个线程发现要扩容，就标记 `transfer` 状态并推进一个 transferIndex，其他线程发现自己也在扩容且未参与，就会协助搬运桶。这比 JDK 7 的分段锁扩容高效得多。

**get 方法的遍历顺序**

《面渣逆袭 Java 集合框架篇》指出 `get` 的查找顺序是：先查数组槽 → 若为红黑树节点则走 `find` → 否则遍历链表。并强调 **HashMap 的 key 应同时重写 hashCode 与 equals**，只重写 equals 会导致两个"逻辑相等"的 key 落到不同桶，get 找不到。

**面试高频结论**

《面试题-02-Java集合容器面试题》给出的对比结论：

| | HashMap | LinkedHashMap | TreeMap |
| --- | --- | --- | --- |
| 底层 | 数组+链表+红黑树 | 数组+链表+红黑树+双链表 | 红黑树 |
| 顺序 | 无序 | 插入序 / 访问序 | key 排序 |
| 查找 | O(1) | O(1) | O(log n) |
| 是否允许 null key | 允许 1 个 | 允许 1 个 | **不允许** |
| 线程安全 | 否 | 否 | 否 |

## 实战提示

**为什么 key 要用不可变对象**：

HashMap 会用 `hashCode()` 定位桶、用 `equals()` 判断是否为同一个 key。如果 key 在放入 Map 后被修改（导致 hashCode 变化），你就再也找不到它了——数据"人间蒸发"。所以 key 应当是 String、Integer 这类不可变对象。

**并发场景的正确选择**：

```java
// 需要并发读写
ConcurrentHashMap<String, Integer> map = new ConcurrentHashMap<>();

// 或者用 ConcurrentHashMap.newKeySet() 替代 HashSet
Set<String> set = ConcurrentHashMap.newKeySet();
```

**排查哈希冲突**：用 `-Djdk.map.althashing.threshold=1`（JDK 8u191+）把树化阈值降到 1，便于快速复现树化路径；或直接用 JOL/反射观察 `table` 数组结构。

**性能提示**：初始化时预估容量，避免多次扩容：

```java
// 预知会放 1000 个元素：new HashMap<>(1000 / 0.75 + 1)
Map<String, Object> map = new HashMap<>(1334);
```

因为扩容不仅耗时，还会**打散原有的链表顺序**（JDK 8 保留相对顺序，但桶位置变了），影响缓存命中率。
' WHERE slug = 'hashmap-red-black-tree';

-- concurrenthashmap
UPDATE lesson SET content = '## 本节要点
分段锁到 CAS 的演进。

## 核心概念
- JDK7 分段锁与 JDK8 CAS + synchronized
- size() 如何无锁统计
- 与 Hashtable 的本质差别

## 关键代码
```
// JDK8 核心：CAS 插入空桶，桶内有元素则 synchronized 锁桶头
if ((tab = table) == null || (n = tab.length) == 0)
    tab = initTable();
else if ((f = tabAt(tab, i = (n - 1) & h)) == null)
    // CAS 成功即插入完成，无需加锁
    if (casTabAt(tab, i, null, newNode(hash, key, val, null)))
        break;
else
    synchronized (f) { /* 锁住桶头节点 */ }
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区
- [''以为分段锁思想还在 JDK8，实际已被 CAS + 桶级锁取代'', ''并发扩容时用 size() 判断业务状态，size 只是估算值'']

## 动手练习
用 16 个线程各写 1 万个 key 到 ConcurrentHashMap，验证无数据丢失。
' WHERE slug = 'concurrenthashmap';

-- set-family
UPDATE lesson SET content = '## 本节要点
元素唯一性的实现原理。

## 核心概念
- HashSet / LinkedHashSet / TreeSet 的差异
- TreeSet 的排序与去重依据
- 选择依据

## 关键代码
```
Set<String> hs = new HashSet<>();          // 无序，hash 去重
Set<String> ls = new LinkedHashSet<>(hs);   // 保持插入顺序
Set<String> ts = new TreeSet<>(Comparator.reverseOrder()); // 按规则排序

// TreeSet 要求元素可比：实现 Comparable 或传 Comparator
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区
- [''用 TreeSet 却不指定比较器，插入不可比元素抛 ClassCastException'', ''误以为 HashSet 能存两个相等的对象，它靠 hashCode + equals 去重'']

## 动手练习
把同一个字符串列表分别存入三种 Set，打印迭代顺序，观察差异。
' WHERE slug = 'set-family';

-- iterator-cmc
UPDATE lesson SET content = '## 本节要点

迭代器的 fail-fast 机制靠 `modCount` 实现：集合每次结构性修改都递增它，迭代器创建时记录快照，遍历中若发现不一致就抛 `ConcurrentModificationException`。这是**尽力而为的错误检测**，不是并发安全保证。

## 核心概念

- **Iterator 接口**：四个方法 `hasNext()`、`next()`、`remove()`。
- **modCount**：ArrayList / HashMap 等的字段，记录结构性修改次数。
- **expectedModCount**：迭代器创建时记录的快照值。
- **fail-fast**：遍历中检测到 modCount 变化立即抛 CME，**尽早暴露 bug**，而不是继续遍历出不确定结果。
- **结构性修改**：改变元素个数或顺序的操作（add/remove/clear）。**修改元素内容不算**（如 `list.set(0, x)` 不触发）。
- **ConcurrentModificationException**：fail-fast 的载体，是**运行时异常**（非受检）。
- **CopyOnWriteArrayList 的迭代器**：**快照式**，遍历时不抛 CME，但也不反映后续修改。
- **弱一致性迭代器**：ConcurrentHashMap 的迭代器，弱一致（可能看到也可能看不到并发修改），但不抛 CME。
- **removeIf 的正确性**：`Collection.removeIf` 默认实现用迭代器，安全；ArrayList 覆写了它做批量优化。

## 关键代码

```java
List<String> list = new ArrayList<>(List.of("a", "b", "c"));
Iterator<String> it = list.iterator();
while (it.hasNext()) {
    String s = it.next();
    if (s.equals("b")) list.remove(s);   // 直接改集合 → fail-fast
}

// 正确做法：用迭代器自身的 remove()
it = list.iterator();
while (it.hasNext()) {
    if (it.next().equals("b")) it.remove();
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 遍历时用集合自身的 remove/delete 导致 CME，其实应用迭代器的 remove
- 给 CopyOnWriteArrayList 频繁写入，数组全量复制导致性能极差
- 认为 CME 是"并发导致的异常"——它其实是**单线程写错了**的信号
- 认为 `set` 也会触发 CME——修改内容不改结构，不触发

## 动手练习

复现一次 ConcurrentModificationException，再用迭代器 remove 修正，对比结果。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Java编程思想第四版》《面渣逆袭 Java 集合框架篇》《二哥的 Java 进阶之路》对本节有深入论述。

**fail-fast 的实现原理**

《Java编程思想第四版》第 11 章给出了 fail-fast 的源码级解释：

```java
public Iterator<E> iterator() {
    return new Itr();   // Itr 是 ArrayList 的内部类
}

private class Itr implements Iterator<E> {
    int expectedModCount = modCount;   // 快照
    ...
    public E next() {
        checkForComodification();       // 每次 next 都校验
        ...
    }
    final void checkForComodification() {
        if (modCount != expectedModCount)
            throw new ConcurrentModificationException();
    }
}
```

**《Java编程思想第四版》特别强调：fail-fast 只是一项「尽力而为」的服务，JDK 承诺尽力检测并发修改，但不保证一定检测到。** 也就是说：CME 出现说明一定有并发修改，但没出现不代表没有并发修改。

**结构性修改的定义**

《二哥的 Java 进阶之路》与《面试题-02-Java集合容器面试题》都列出了哪些操作会触发 modCount 变化：

| 操作 | 是否结构性修改 |
| --- | --- |
| `add` / `remove` / `clear` / `addAll` / `removeAll` / `retainAll` | [OK] 是 |
| `set(index, e)` | [X] 否（只改内容） |
| `sort` / `replaceAll` | [X] 否（不改变元素个数） |

注意 `sort` 虽然不改变 modCount，但它会改变元素顺序——这正是 fail-fast 的一个**盲区**：排序后继续遍历可能读到"错位"的数据却不报错。

**CopyOnWriteArrayList 的快照迭代器**

《面渣逆袭 Java 集合框架篇》指出 CopyOnWriteArrayList 的迭代器持有的是**创建迭代器那一刻**的数组快照：

```java
public Iterator<E> iterator() {
    return new COWIterator<>(getArray());   // 传入当前数组的引用
}
```

这带来两个特性：
1. 遍历中修改集合**不会抛 CME**（迭代器看不到变化）
2. 迭代器**看不到**创建之后的修改

所以 CopyOnWriteArrayList 适合「注册监听器列表」这类读多写少的场景，而不是需要实时一致性的场景。

**ConcurrentHashMap 的弱一致迭代器**

《二哥的 Java 进阶之路》与《面渣逆袭 Java 集合框架篇》指出，ConcurrentHashMap 的迭代器是**弱一致（weakly consistent）**的：

- 遍历过程中若有并发修改，迭代器可能看到、也可能看不到被修改的元素
- 但**不会抛 CME**，也不会导致无限循环
- 这是为了保证遍历效率——若采用 fail-fast，就要给每次遍历加全局锁

**增强 for 与迭代器的等价关系**

《Java编程思想第四版》明确指出增强 for 循环编译后就是 Iterator 循环，因此**在增强 for 里删除元素同样会 CME**：

```java
for (String s : list) {
    if (s.isEmpty()) list.remove(s);   // CME！
}
```

**并发集合与 fail-fast 的取舍**

《面渣逆袭 Java 集合框架篇》给出结论：并发集合选择**弱一致性**而非 fail-fast，因为在真实并发场景下，「检测到并发修改就抛异常」几乎无法恢复——你无法通过捕获 CME 来安全地继续处理。弱一致性牺牲了实时准确性，换来的是可用的并发语义。

## 实战提示

**按条件删除的三种正确写法**：

```java
// 1. removeIf（推荐，内部用迭代器，无 CME 风险）
list.removeIf(s -> s.isEmpty());

// 2. 迭代器 remove
Iterator<String> it = list.iterator();
while (it.hasNext()) {
    if (it.next().isEmpty()) it.remove();
}

// 3. Java 8 的 replaceAll + removeIf 组合
list.replaceAll(s -> s.trim());
list.removeIf(String::isEmpty);
```

**注意 `remove` 的重载陷阱**：

```java
list.remove(1);          // 删除下标 1 的元素（int）
list.remove(Integer.valueOf(1));  // 删除值为 1 的元素
```

传 `int` 字面量永远走下标重载。删除元素一律用 `removeIf` 或 `remove(Object)`（显式装箱）。

**CME 的正确处理方式**：它不是"偶发异常可以 catch 掉重试"——catch 之后继续遍历仍然是不确定的。正确做法是**改写代码**，不要 catch CME。

**排查 CME 的思路**：

1. 看堆栈里 `checkForComodification` 的调用位置
2. 确认是不是在遍历时调用了集合的增删方法（包括间接的，如 `list.forEach(x -> list.remove(...))`）
3. 若是并发场景，改用并发集合（ConcurrentHashMap / CopyOnWriteArrayList）
' WHERE slug = 'iterator-cmc';

-- stream-api
UPDATE lesson SET content = '## 本节要点

Stream 把集合操作从「描述怎么做」变成「描述要什么」。核心特征是**惰性求值**——中间操作只构建流水线，真正干活的是终端操作。`Collectors` 承担了分组、聚合、汇总三大职责。

## 核心概念

- **Stream 不是集合**：不存储数据，是数据处理的视图。
- **惰性求值**：中间操作（filter/map/sorted/limit）返回新 Stream，不立即执行；只有终端操作（collect/forEach/count/anyMatch）触发真正的遍历。
- **流只能消费一次**：终端操作后流就关闭了，再用会抛 `IllegalStateException`。
- **中间操作**：filter、map、flatMap、distinct、sorted、limit、skip、peek。
- **终端操作**：collect、forEach、reduce、count、min/max、anyMatch/allMatch/noneMatch、findFirst/findAny。
- **Collectors**：groupingBy（分组）、partitioningBy（按布尔分组）、toMap、counting、summing、averaging、joining、summarizing、mapping、collectingAndThen。
- **短路操作**：findFirst、anyMatch、limit、takeWhile——找到结果即停止。
- **并行流**：使用 ForkJoinPool.commonPool()，适合纯计算、大数据量、无共享状态。
- **peek 的陷阱**：只有终端操作执行后 peek 才会真正跑，调试时容易误判。

## 关键代码

```java
List<Order> orders = getOrders();

// 分组统计：每个用户的订单数和总金额
Map<Long, Stats> stats = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId,
            Collectors.collectingAndThen(
                    Collectors.toList(),
                    list -> new Stats(list.size(), list.stream()
                            .mapToDouble(Order::getAmount).sum()))));

// filter 中有状态且已并行时才有意义
orders.parallelStream()
    .filter(o -> o.getAmount() > 100)
    .map(Order::getUserName)
    .forEach(System.out::println);
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 在 Stream 里做副作用操作（println、修改外部变量），破坏可读性
- 对数据量小的集合用并行流，线程调度开销反而更慢
- 以为 `peek` 是"调试专用"，其实它是有副作用的操作，只是常用于调试
- 在终端操作之前多次调用 `filter` 后以为会重复遍历——惰性求值下只遍历一次

## 动手练习

把一个订单列表按用户分组，输出每个用户的订单数与总金额。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《二哥的 Java 进阶之路暗黑版》《深入理解高并发编程（第 2 版）》《Java多线程开发最佳实践手册》《面渣逆袭Java并发编程》对本节的方法论有支撑。

**Stream 的惰性求值与流水线**

《二哥的 Java 进阶之路暗黑版》与《深入理解高并发编程（第 2 版）》都强调 Stream 的处理链路是**惰性**的：

```
数据源 → filter → map → sorted → collect
         ↑ 中间操作只构建流水线，不执行
                                   ↑ 终端操作触发一次性遍历
```

这个模型解释了几个现象：

- `stream().filter(...)` 之后不做终端操作，**什么都不会发生**
- 一个流只能被消费一次，因为终端操作会关闭它
- `sorted()` 在并行流中开销大——它必须**收集全部元素后排序**（有状态操作需要完整缓冲区）

**Collectors 的分组能力**

《二哥的 Java 进阶之路》与《面渣逆袭Java并发编程》都演示了 groupingBy 的三种形式：

```java
// 1. 按 key 分组，value 是列表
Map<Long, List<Order>> byUser = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId));

// 2. 分组后立即汇总（下游收集器）
Map<Long, Long> countByUser = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId, Collectors.counting()));

// 3. 分组 + 映射 + 汇总（组合下游）
Map<Long, Double> sumByUser = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId,
            Collectors.summingDouble(Order::getAmount)));

// 按布尔分区（两桶，key 固定为 true/false）
Map<Boolean, List<Order>> big = orders.stream()
    .collect(Collectors.partitioningBy(o -> o.getAmount() > 100));
```

**toMap 的两个坑**

《二哥的 Java 进阶之路》特别提醒 `Collectors.toMap` 的两个问题：

```java
// 坑1：value 为 null 会抛 NPE
Collectors.toMap(Order::getId, Order::getRemark)   // remark 为 null → NPE

// 解决：用 merge 的三参数版本
Collectors.toMap(Order::getId, Order::getRemark, (a, b) -> a)

// 坑2：key 重复会抛 IllegalStateException
Collectors.toMap(Order::getUserId, Order::getId)  // 同用户多单 → 异常
```

**下游收集器（Downstream Collector）**

《深入理解高并发编程（第 2 版）》与《Java多线程开发最佳实践手册》都介绍了 `collectingAndThen` 的组合模式：

```java
// 先收集，再对结果做一次转换
Map<Long, String> userNames = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId,
            Collectors.collectingAndThen(
                    Collectors.mapping(Order::getUserName, Collectors.toList()),
                    names -> String.join(",", names))));
```

**并行流与 Collectors 的线程安全**

《Java多线程开发最佳实践手册》指出，并行流中 Collectors 的实现必须**线程安全**——JDK 提供的实现（`toList`、`groupingBy`）都用了并发容器合并结果，但自定义 Collector 时必须自己保证 `combiner()` 的正确性：

```java
// 自定义 Collector 的 combiner 负责合并两个分片的结果
Collector<Order, ?, Map<Long, List<Order>>> myCollector =
    Collector.of(
        ArrayList::new,                 // supplier
        (list, o) -> list.add(o),       // accumulator
        (l1, l2) -> { l1.addAll(l2); return l1; },  // combiner（并行必需）
        Collector.Characteristics.IDENTITY_FINISH);
```

**Stream 与循环的取舍**

《二哥的 Java 进阶之路》与《深入浅出Java+23种设计模式》都提到 Stream 的真正价值在**可读性**而非性能：

- 简单遍历：for 循环更直白
- 多步变换 + 聚合：Stream 表达力明显更强
- 需要索引、break、continue：Stream 不便（用 `findFirst` / `takeWhile` 替代）

## 实战提示

**Collectors 全景速查**：

| 用途 | 方法 |
| --- | --- |
| 转集合 | `toList()` / `toSet()` / `toCollection(LinkedHashSet::new)` |
| 分组 | `groupingBy` / `partitioningBy` |
| 映射 | `mapping` |
| 计数 | `counting()` |
| 求和 | `summingInt/Double/Long` |
| 平均 | `averagingInt/Double/Long` |
| 最值 | `maxBy` / `minBy` |
| 汇总统计 | `summarizingInt/Double/Long`（含 count/sum/min/max/avg） |
| 拼接 | `joining(delimiter, prefix, suffix)` |
| 转换后汇总 | `collectingAndThen` |

**调试 Stream 的正确方式**：

```java
// peek 必须在终端操作之前，否则不会执行
list.stream()
    .peek(s -> System.out.println("处理: " + s))
    .filter(s -> s.length() > 3)
    .collect(Collectors.toList());
```

`peek` 的位置很关键——放在 `filter` 之前看到的是全部元素，放在之后只看到通过过滤的元素。

**并行流的判断标准**：

| 场景 | 建议 |
| --- | --- |
| 纯计算 + 数据量大（>10万）+ 无共享状态 | 用并行流 |
| 涉及 IO / 远程调用 | 用 CompletableFuture + 独立线程池 |
| 数据量小（<1万） | 串行更快 |
| 操作有副作用（写数据库、打印） | **不要并行**（顺序不确定） |

**性能陷阱**：并行流下 `Collectors.toList()` 虽安全但有额外开销；数据量不大时并行流普遍比串行慢。真正需要性能时用 JMH 测量，而不是凭感觉。

**Stream 的短路能力常被忽视**：

```java
// 遇到第一个满足条件就停 —— 大数据量下能省大量计算
Optional<Order> first = orders.stream()
    .filter(o -> o.getAmount() > 10000)
    .findFirst();

// Java 9+ 的 takeWhile：遇到不满足就停（与 filter 的区别）
List<Order> prefix = orders.stream()
    .takeWhile(o -> o.getAmount() > 100)   // 遇到 <=100 立即停止
    .collect(Collectors.toList());
```
' WHERE slug = 'stream-api';

-- project-stream-refactor
UPDATE lesson SET content = '## 本节要点
把一段 200 行的 for 循环改成 20 行 Stream。

## 核心概念
- 从命令式到声明式的重构思路
- 何时该停止抽象
- 可读性与性能的平衡

## 关键代码
```
// 命令式：三层嵌套过滤
List<String> result = new ArrayList<>();
for (Order o : orders) {
    if (o.getStatus() == PAID) {
        if (o.getAmount() > 100) {
            result.add(o.getUserName());
        }
    }
}

// 声明式：一次表达意图
List<String> result2 = orders.stream()
    .filter(o -> o.getStatus() == PAID)
    .filter(o -> o.getAmount() > 100)
    .map(Order::getUserName)
    .toList();
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区
- [''把简单循环硬改成 Stream，可读性反而下降'', ''链路过长（一行塞 10 个操作），难以调试'']

## 动手练习
把手写的一道统计题用 Stream 重写，再对照两版代码的行数与可读性。
' WHERE slug = 'project-stream-refactor';

-- jvm-memory
UPDATE lesson SET content = '## 本节要点

JVM 把内存划分为「线程私有区」与「线程共享区」两大部分：程序计数器、虚拟机栈、本地方法栈随线程生死；堆、方法区由所有线程共享，也正是 GC 的主战场。JDK 8 起方法区的实现从永久代换成了元空间，前者位于堆内、后者位于本地内存。

## 核心概念

- **程序计数器（PC Register）**：线程私有，记录当前线程正在执行的字节码指令行号。执行 native 方法时它的值为 undefined，是唯一一个不会 OOM 的内存区域。
- **虚拟机栈**：每次 Java 方法调用都创建一个**栈帧**（局部变量表、操作数栈、动态链接、方法引用），栈帧是基本单位。线程私有，深度不足抛 StackOverflowError。
- **本地方法栈**：为 native 方法服务，HotSpot 中与虚拟机栈合二为一。
- **堆**：所有线程共享，对象实例与数组的存放地，由各线程共享的 GC 管理。
- **方法区**：存放类型信息、运行时常量池、方法数据。JDK 8 前是永久代（堆内 `-XX:PermSize`），JDK 8 后是**元空间**（本地内存 `-XX:MetaspaceSize`）。
- **内存溢出的两种典型形态**：堆溢出 `OutOfMemoryError: Java heap space`（对象撑爆堆）；栈溢出 `StackOverflowError`（递归层数过深）。

## 关键代码

```java
// 堆：所有线程共享，存放对象实例，GC 主战场
Student s = new Student();     // 对象在堆上

// 栈：线程私有，存放局部变量表与操作数栈
void foo() {
    int a = 10;        // a 的值在当前线程栈的局部变量表
    String b = "hi";   // b 的引用在栈，字符串对象在堆
}

// 典型溢出
List<byte[]> leak = new ArrayList<>();  // 堆溢出：OutOfMemoryError: Java heap space
void recurse() { recurse(); }           // 栈溢出：StackOverflowError
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为基本类型也在堆上，其实局部基本类型在栈
- 分不清 StackOverflowError 与 OutOfMemoryError 的成因
- 认为元空间也会 OOM 于堆中，实际它用的是本地内存，堆再大也救不了元空间溢出

## 动手练习

写一个递归方法让它栈溢出，再写一个死循环往 List 里加对象让它堆溢出，观察报错差异。

## 延伸阅读（来自「Java江湖」知识库）

本节要点参考了知识库中的《doocs-jvm》《深入理解 JVM 核心技术》《二哥的 JVM 进阶之路》《深入理解 Java 虚拟机（第 3 版）》与《面渣逆袭 JVM》等资料，可对照以下知识点自查：

**运行时数据区的完整划分**

知识库中《doocs-jvm》开篇即给出 JVM 内存空间的五个部分：程序计数器、虚拟机栈、本地方法栈、堆、方法区。与本节相比，最容易被忽略的是**本地方法栈**——它并非可有可无，而是 JVM 规范中独立划分的区域，只是 HotSpot 实现把它与虚拟机栈合并为同一块内存。

**JDK 8 的关键变化：元空间取代永久代**

《doocs-jvm》明确指出：JDK 1.8 相对 1.7 最大的差别就是元数据区取代了永久代。元空间的本质与永久代类似，都是对 JVM 规范中方法区的实现，但**元空间并不在虚拟机中，而是使用本地内存**。这一点直接决定了生产环境的调优姿势不同：

- 永久代时代用 `-XX:PermSize` / `-XX:MaxPermSize` 控制上限
- 元空间时代改用 `-XX:MetaspaceSize`（首次触发元空间 GC 的阈值）与 `-XX:MaxMetaspaceSize`

**对象访问方式：句柄访问与直接指针**

《doocs-jvm》在讲对象访问时指出，堆中需要有一块叫做「句柄池」的区域。这对应 JVM 规范里的两种对象访问方式：

| 访问方式 | 栈帧中存什么 | 优点 | 缺点 |
| --- | --- | --- | --- |
| 句柄访问 | 对象的句柄地址 | 指针移动时只需改句柄，引用稳定 | 多一次间接寻址 |
| 直接指针 | 对象内存地址 | 访问快，少一次寻址 | GC 移动对象时需修正所有引用 |

HotSpot 默认使用**直接指针**。这个知识点常被跳过，但它解释了为什么 GC 移动对象时必须修正引用——如果用句柄访问，只需改句柄池中的指针，工作量小得多。

**GC Roots 与可达性分析**

GC 并非扫描整个堆，而是从一组 GC Roots 出发做可达性分析。《二哥的 JVM 进阶之路》给出的 GC Roots 清单是：

- 虚拟机栈中引用的对象
- 方法区中静态属性引用的对象
- 方法区中常量引用的对象
- 本地方法栈中 JNI 引用引用的对象

**常量池与类型卸载**

《doocs-jvm》提到方法区回收的两个目标：对常量池的回收，以及**对类型的卸载**。类型卸载的条件相当苛刻：必须满足「该类的所有实例都已被回收」「加载该类的 ClassLoader 已被回收」「该类对应的 Class 对象没有被任何地方引用」。这解释了为什么动态生成类（如大量使用 CGLIB 代理、脚本引擎）的应用容易出现元空间泄漏——每次代理都会生成一个新的类，元空间只增不减。

**内存区域概览速查**

《深入理解 JVM 核心技术》把「JVM 内存区域概览」作为独立小节展开，可作为画图记忆的骨架；《深入理解 Java 虚拟机（第 3 版）》第 2 章标题即「Java 内存区域与内存溢出异常」，第 3 章讲「垃圾收集」，两者构成本节的权威对照。

## 实战提示

排查内存问题前先分清是哪个区域出的问题：

- `java.lang.OutOfMemoryError: Java heap space` → 堆，需要看对象占用与 GC 日志
- `java.lang.OutOfMemoryError: Metaspace` → 元空间，通常是动态类或代理类泄漏
- `java.lang.StackOverflowError` → 栈，检查递归深度
- `java.lang.OutOfMemoryError: unable to create new native thread` → 线程数过多或系统句柄耗尽
' WHERE slug = 'jvm-memory';

-- object-layout
UPDATE lesson SET content = '## 本节要点

对象在堆中的内存布局由三部分组成：**对象头**（Mark Word + 类型指针）、**实例数据**、**对齐填充**。64 位 HotSpot 上对象头是 12 字节（压缩指针开启时）或 16 字节，整体大小还要按 8 字节对齐补齐。

## 核心概念

- **Mark Word**：64 位占 8 字节，存储对象的哈希码、GC 年龄、锁状态标志（无锁/偏向/轻量级/重量级）等；32 位只占 4 字节。
- **类型指针（Klass Pointer）**：指向类元数据，用于确定对象类型，压缩指针开启时占 4 字节。
- **实例数据**：字段的实际值，基本类型按字段声明顺序排列，引用类型 4 字节（压缩指针）。
- **对齐填充**：为了对齐填充的字节，HotSpot 按 8 字节对齐。
- **字段重排优化**：JVM 会把相同类型大小的字段排在一起，减少填充浪费。
- **压缩指针（Compressed Oops）**：用 32 位表示对象引用（堆 ≤ 32GB 时生效），`-XX:+UseCompressedOops`。
- **分代的意义**：对象朝朝代亡者占多数 => 少部分区域频繁回收。

## 关键代码

```java
// 一个空对象在 64 位 JVM 上占 16 字节：12 字节对象头 + 4 字节对齐
Object o = new Object();          // 16 bytes

// 加一个 int 字段后仍是 16 字节（补齐对齐）
class A { int i; }                 // 12 + 4 = 16

// 加两个 int 后变 24（8 字节对齐）
class B { int i; int j; }          // 12 + 8 = 20 -> 对齐到 24

// 压缩指针（默认开启）：4 字节表示引用，堆 ≤32G 时生效
// -XX:+UseCompressedOops
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 只记「对象有对象头」却不知道 64 位下是 12 字节
- 以为引用一定是 8 字节，忽略了压缩指针
- 以为字段重排会自动补齐掉所有空洞，实际上只能在同类字段内部调整顺序

## 动手练习

用 JOL（Java Object Layout）工具打印多个类的实例大小，观察字段排列与补齐。

## 延伸阅读（来自「Java江湖」知识库）

本节的知识点在知识库中可对照《doocs-jvm》《深入理解 Java 虚拟机（第 3 版）》第 2 章、以及《面渣逆袭 JVM》中「8. 能说一下对象的内存布局吗？」一节。

**对象头里的锁状态标志**

《doocs-jvm》明确指出对象头中存有「**锁状态标志**」。这是对象布局与并发最直接的交叉点：Mark Word 里预留了 4 位（实际更多）用于标记偏向锁、轻量级锁、重量级锁的状态。理解它就能明白：

- 无锁状态：Mark Word 存 identity hashCode + 分代年龄
- 偏向锁状态：Mark Word 存线程 ID（偏向锁已在 JDK 15 后废弃，默认关闭）
- 轻量级锁状态：Mark Word 存指向栈中锁记录的指针
- 重量级锁状态：Mark Word 存指向 monitor 的指针

**class 文件结构中的 u2/u4/u8**

《doocs-jvm》在讲 class 文件格式时给出了「u2、u4、u8 分别代表……」的说明，这正是理解对象内存布局的另一半——JVM 需要先从 class 文件里读出字段描述，才能算出实例数据占多少字节：

| 类型 | 字节数 | 含义 |
| --- | --- | --- |
| u1 | 1 | 无符号 8 位整数 |
| u2 | 2 | 无符号 16 位整数（字段数量、方法数量用） |
| u4 | 4 | 无符号 32 位整数（字段名索引、属性长度用） |
| u8 | 8 | 无符号 64 位整数（double、long 常量用） |

**对象的创建过程**

《doocs-jvm》提到「调用对象的构造函数方法进行初始化」。完整的对象创建链路是：分配内存 → 内存零初始化 → 设置对象头（类型指针、哈希码、GC 年龄）→ 执行 `<init>` 方法。设置对象头这一步正对应本节讲的对象头布局。

**锁升级与对象头的关系**

《二哥的 JVM 进阶之路》与《深入理解 JVM 核心技术》都提到「锁状态标志」与「转换为红黑树链表转换为红黑树过程」等运行时状态变化。对象头里的这几位标志位不是装饰——JVM 通过修改它们来记录对象当前被哪种锁保护。这也解释了 `synchronized` 的锁升级路径：无锁 → 偏向锁（已废弃）→ 轻量级锁 → 重量级锁，每一步都只改 Mark Word 的几个位，不改对象本身的结构。

## 实战提示

排查内存占用时，用 JOL 打印实际布局而不是估算：

```java
// 依赖：org.openjdk.jol:jol-core
System.out.println(ClassLayout.parseInstance(new B()).toPrintable());
```

输出会逐字段列出偏移量（offset）与大小，能直观看到「空洞 padding」是如何被引入的。若 padding 占比过高，说明字段声明顺序需要调整（例如把 boolean 字段集中声明在一起）。
' WHERE slug = 'object-layout';

-- class-loading
UPDATE lesson SET content = '## 本节要点

类的生命周期要经历七个阶段：加载 → 验证 → 准备 → 解析 → 初始化 → 使用 → 卸载，其中前五个构成类加载过程。核心机制是**双亲委派模型**：类加载请求先委派给父加载器，父加载器无法完成才由自己加载。

## 核心概念

- **加载（Loading）**：通过全限定名获取二进制字节流 → 定义为运行时数据区结构 → 生成 Class 对象。
- **验证（Verification）**：确保字节码符合规范，不会危害虚拟机安全，且不会破坏正确性。
- **准备（Preparation）**：为类变量分配内存并设置初始值。注意：这里的「初始值」是**零值**（int 为 0、引用为 null），不是源码里的赋值表达式。
- **解析（Resolution）**：把常量池中的符号引用替换为直接引用（可以延后到真正使用时）。
- **初始化（Initialization）**：执行类构造器 `<clinit>`，按源码顺序执行静态变量赋值与静态代码块。
- **双亲委派模型**：Bootstrap → Extension → Application → 自定义，先问父，父不行才自己干。
- **破坏双亲委派**：SPI、OSGi、热部署都依赖自定义 ClassLoader 打破委派顺序。
- **类加载的时机**：首次主动使用（new、访问静态字段、反射、初始化子类等）时加载；解析可延后。

## 关键代码

```java
// 双亲委派：先问父加载器，父搞不定才自己加载
protected Class<?> loadClass(String name, boolean resolve) {
    Class<?> c = findLoadedClass(name);
    if (c == null) {
        try {
            c = parent.loadClass(name, false);   // 1. 父加载器
        } catch (ClassNotFoundException e) {
        }
        if (c == null) c = findClass(name);      // 2. 自己加载
    }
    return c;
}
// 破坏双亲委派：SPI、OSGi、热部署都靠自定义 ClassLoader
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 `Class.forName` 一定初始化类，其默认不会执行静态块
- 把类名写错导致 ClassNotFoundException，却以为是包路径问题
- 认为「准备阶段会给静态变量赋源码里的值」，其实准备阶段赋的是零值

## 动手练习

自定义一个 ClassLoader，把某个 class 文件字节数组 define 进去，独立加载一份与主类同名的类。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《JVM 类加载器详解》《doocs-jvm》《深入理解 JVM 核心技术》《深入理解 Java 虚拟机（第 3 版）》对本节覆盖非常完整，其中《JVM 类加载器详解》开篇就给出了一张「类加载器作用 / 加载路径 / 范围 / 实现」的对照表。

**四类类加载器及各自的加载范围**

《JVM 类加载器详解》给出的实现清单是：

| 类加载器 | 实现语言 | 加载范围 | 典型路径 |
| --- | --- | --- | --- |
| 启动类加载器（Bootstrap ClassLoader） | C++ | JVM 核心类库（java.lang.*、java.util.*） | `JAVA_HOME/jre/lib` 下的核心 jar（rt.jar） |
| 扩展类加载器（Extension ClassLoader） | Java | JVM 扩展类库（javax.*） | `JAVA_HOME/jre/lib/ext` |
| 应用程序类加载器（Application ClassLoader） | Java | 应用程序类路径下的类 | classpath |
| 自定义类加载器 | Java | 由开发者指定 | 自行指定 |

启动类加载器是**唯一不继承 ClassLoader 的**加载器——它由 C++ 实现，是虚拟机自身的一部分。

**类加载的时机与初始化条件**

《doocs-jvm》专门列出「类加载的时机」，而《深入理解 JVM 核心技术》则给出了更精确的「类初始化的条件」：

- 主动使用：new、访问/赋值静态字段、反射调用、初始化子类时先初始化父类、启动类（main 方法所在类）
- **被动使用**（不触发初始化）：通过子类引用父类静态字段、父类 Class 对象、引用常量（编译期常量会被直接内联到调用方，不触发加载）

**双亲委派的破坏**

知识库中《深入理解 Java 虚拟机（第 3 版）》与《深入浅出 Java 多线程》都提到自定义类加载器的存在意义。SPI 是最典型的例子：`ServiceLoader` 从 `META-INF/services` 读实现类名，而 `java.sql.DriverManager` 由 Bootstrap 加载器加载，它无法找到应用层的驱动实现——**这正是主动打破双亲委派的地方**，自定义的线程上下文类加载器（Thread Context ClassLoader）负责加载 SPI 实现。

**类卸载的条件**

《doocs-jvm》指出方法区回收的两个目标是对常量池的回收与**对类型的卸载**。类型卸载需要同时满足三个条件：

1. 该类的所有实例都已被回收（堆中不再存在该类的对象）
2. 加载该类的 ClassLoader 已被回收
3. 该类对应的 Class 对象没有被任何地方引用（`Class.forName`、反射持有的引用都会阻止卸载）

这三条合起来解释了一个生产现象：大量使用动态代理或脚本引擎的应用，元空间只增不减——每次调用都会生成一个新的类，而这些类永远无法卸载。

## 实战提示

排查「类明明写了却找不到」时，按双亲委派链路自下而上检查：

```java
// 打印各类加载器及其加载范围
ClassLoader cl = MyClass.class.getClassLoader();
while (cl != null) {
    System.out.println(cl);   // Application → Platform → null(bootstrap)
    cl = cl.getParent();
}
System.out.println(cl);       // null 表示已到 Bootstrap
```

- `ClassNotFoundException` → 应用类加载器路径没覆盖，检查 jar 包与 classpath
- `NoClassDefFoundError`（初始化后失败）→ 类在但初始化抛过异常，用 `-XX:+ShowClassInitializationExceptions` 看真实原因
- `LinkageError: loader constraint violation` → 同一个类被两个加载器各加载了一份，典型于 SPI 与 Tomcat 的类冲突
' WHERE slug = 'class-loading';

-- gc-algorithms
UPDATE lesson SET content = '## 本节要点

垃圾回收先判断「谁是垃圾」（可达性分析 + 三色标记），再决定「怎么回收」（标记清除、复制、标记整理）。分代收集把这两件事拆开：新生代用复制算法，老年代用标记清除或标记整理。CMS 与 G1 的差别，本质是**整理方式与并发程度**的差别。

## 核心概念

- **可达性分析**：从 GC Roots 出发遍历引用链，不可达的对象即为垃圾。解决了「引用计数无法处理循环引用」的问题。
- **三色标记**：白 = 待扫描，灰 = 已标记但子节点未扫描，黑 = 已标记且子节点已扫描。GC 线程是**黑色 → 白色**的增量更新（SATB），用户线程是**黑色 → 黑色**（增量更新，CMS 用）。
- **GC Roots**：虚拟机栈中引用的对象、静态字段引用的对象、常量池引用的对象、JNI 引用的对象。
- **分代假说**：绝大多数对象朝生夕死；越老的对象存活越久。
- **Minor GC / Young GC**：复制算法，只动 Eden + Survivor，把存活对象复制到另一个 Survivor。频繁、代价低。
- **Full GC / Major GC**：老年代回收，标记清除或标记整理，STW 时间长。
- **CMS（Concurrent Mark Sweep）**：并发标记清除，STW 时间短，但会产生**碎片**，且并发阶段与用户线程抢占 CPU。
- **G1（Garbage First）**：把堆划分为 Region，按「垃圾含量」优先级回收，用 **Remembered Set** 记录跨 Region 引用，用 SATB 保证并发标记正确性。目标是可预测的停顿时间。

## 关键代码

```java
// 三色标记：白=待扫描，灰=已标记未扫描子节点，黑=已完成
// GC Roots
// ├─ 虚拟机栈中引用的对象
// ├─ 静态字段引用的对象
// ├─ 常量池引用的对象
// └─ JNI 引用的对象

// 分代收集
// 新生代 Eden:Survivor8:1 → Minor GC（频繁、代价低）
// 老年代 Full GC（STW 时间长），对象熬过 15 次晋升
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 GC 越频繁越健康，频繁 Minor GC 反而说明对象分配太快
- 手动调大新生代却忽略业务对象生命周期，导致老年代持续增长
- 认为 CMS 是"完全并发"的——初始标记与最终标记仍是 STW，只是很短
- 以为 G1 一定比 CMS 快——G1 的优势是**停顿时间可预测**，不是吞吐量一定更高

## 动手练习

用 JVisualVM 或 Arthas 的 dashboard 观察分代大小变化，对比两次 GC 之间的分配速率。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《doocs-jvm》《深入理解 Java 虚拟机（第 3 版）》《二哥的 JVM 进阶之路》《面渣逆袭 JVM》以及《面试题-08-Java虚拟机(JVM)面试题》对本节覆盖非常完整。

**三种基本回收算法的适用场景**

《doocs-jvm》把回收算法与分代直接对应：

| 算法 | 思路 | 优点 | 缺点 | 适用 |
| --- | --- | --- | --- | --- |
| 标记清除 | 标记存活对象，其余清除 | 不需移动对象 | 产生碎片 | 老年代 |
| 复制 | 复制存活对象到另一空间 | 无碎片，分配快 | 空间浪费一半 | 新生代 |
| 标记整理 | 标记存活对象并向一端移动 | 无碎片 | 移动对象成本高 | 老年代 |

《doocs-jvm》中标注「标记-整理算法（老年代）」，正是这个对应关系的出处。

**G1 与 CMS 的对比**

《深入理解 Java 虚拟机（第 3 版）》中专门讨论了「G1 收集器常会被拿来与 CMS」做对比，两者的关键差异：

- **内存布局**：CMS 要求连续的新生代/老年代分区；G1 把堆划分为大小相等的 Region，逻辑上仍分代但物理上不连续
- **回收粒度**：CMS 以「老年代」为单位；G1 以 Region 为单位，可以只回收垃圾最多的那部分
- **停顿目标**：CMS 目标是「降低 STW 时间」；G1 目标是「**可预测的停顿时间**」，通过 `-XX:MaxGCPauseMillis` 指定目标
- **碎片**：CMS 标记清除会产生碎片，需依赖 Full GC 整理；G1 的复制算法天然无碎片
- **内存占用**：G1 需要 Remembered Set 记录跨 Region 引用，有额外内存开销

**并发回收时的线程数**

《深入理解 JVM 核心技术》提到「并发回收时垃圾收集线程不少于……」这一细节——CMS 的并发阶段由若干 GC 线程与用户线程同时运行，这意味着 GC 会与业务线程**争抢 CPU**。在高 QPS 场景下，这一点常被忽视：CPU 核数不多时，并发 GC 反而会拖慢业务线程。

**STW 的两类**

《面渣逆袭 JVM》与《面试题-08》都强调「并行」与「并发」在 GC 中的不同含义：

- **并行（Parallel）**：GC 线程之间并行工作，但仍然会 STW（暂停所有 Java 线程）
- **并发（Concurrent）**：GC 线程与用户线程同时工作，只有部分阶段 STW（如初始标记、最终标记）

**主动触发 GC 的方式**

《面试题-08-Java虚拟机(JVM)面试题》把「垃圾回收器可以马上回收内存吗？有什么办法主动通知虚拟机进行垃圾回收？」列为高频问答题，答案是通过 `System.gc()`（提示，非强制）与 `Runtime.getRuntime().gc()`。生产环境应慎用，因为它会触发 Full GC。

**引用类型与可达性判定**

同一份面试题资料还问到「Java 中都有哪些引用类型？怎么判断对象是否可以被回收？」：

| 引用类型 | 回收时机 |
| --- | --- |
| 强引用 | 永不回收（GC Root 可达） |
| 软引用 SoftReference | 内存不足时才回收 |
| 弱引用 WeakReference | 下次 GC 必定回收 |
| 虚引用 PhantomReference | 不决定生命周期，仅用于跟踪回收与堆外内存管理 |

## 实战提示

GC 调优的第一步永远是**看日志，而不是猜参数**：

```bash
# 打印 GC 日志与分配信息（JDK 9+ 统一日志格式）
java -Xlog:gc*,safepoint:file=gc.log:time,uptime:level,tags:filecount=5,filesize=20M -jar app.jar

# 实时观察分代与 GC 情况
jstat -gcutil <pid> 1000
```

`-Xlog:gc*` 输出中重点看三个指标：

1. **停顿时间**（Pause Young / Pause Full）——决定用户体验
2. **晋升速率**——老年代增长过快说明对象生命周期过长或新生代太小
3. **Full GC 频率**——持续 Full GC 基本等于线上事故

JDK 9+ 已把 Parallel GC 设为默认收集器。它在小堆、延迟敏感的场景反而优于 G1：吞吐更高、停顿更短。只有当堆较大（数 GB 以上）且需要控制停顿上界时，才值得切到 G1。
' WHERE slug = 'gc-algorithms';

-- jvm-tuning-tools
UPDATE lesson SET content = '## 本节要点

JVM 调优有两把钥匙：**GC 日志**告诉你「发生了什么」，**线程栈/堆快照**告诉你「为什么」。工具链上，`jstat` 看趋势、`jmap` 打快照、`jstack` 看线程、`jcmd` 聚合入口、`jconsole`/`VisualVM` 做可视化。

## 核心概念

- **jstat**：按指定间隔输出类加载、垃圾回收、编译、运行时内存等统计，是排查「内存是否泄漏」的第一站。
- **jmap**：生成堆转储（dump）、打印类信息、统计实例。是分析对象占用的核心工具。
- **jstack**：打印各线程的堆栈快照，定位死锁、线程卡死、CPU 飙高。
- **jcmd**：JDK 7+ 的统一诊断入口，`jcmd <pid> help` 列出全部能力。
- **GC 日志**：JDK 9+ 统一为 `-Xlog:` 语法，是判断停顿原因最直接的证据。
- **OOM 三类**：堆溢出、元空间溢出、线程创建失败——定位路径完全不同。
- **堆转储分析**：MAT / VisualVM 看 dominator tree，能直接指出「谁占着内存」。

## 关键代码

```java
// 运行时取堆信息（代码内诊断用）
Runtime rt = Runtime.getRuntime();
long total = rt.totalMemory() / 1024 / 1024;   // 已分配
long free  = rt.freeMemory()  / 1024 / 1024;   // 空闲
long max   = rt.maxMemory()   / 1024 / 1024;   // 上限
System.out.printf("堆: %dM/%dM (上限 %dM)%n", total - free, total, max);

// 线程数
Thread.activeCount();

// 可达性分析辅助：主动触发一次 GC 再观察回收效果
System.gc();
Thread.sleep(200);
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 `System.gc()` 能可靠触发 Full GC，它只是一个提示，多数实现会直接忽略
- 只看 Heap Used 就下结论"内存泄漏"，实际要看对象数量与 dominator tree
- 用 `kill -9` 抓 dump，导致 dump 文件不完整无法分析
- 认为调大堆就能解决所有 OOM，元空间与线程的问题跟堆大小无关

## 动手练习

用 Arthas 的 dashboard 命令观察进程运行状态，并尝试用 trace 命令观察某个方法的耗时分布。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《JVM 调优工具》《二哥的 JVM 进阶之路》《深入理解 Java 虚拟机（第 3 版）》对本节工具链有直接覆盖。

**jstat 各选项的用途**

《JVM 调优工具》开篇就给出了 jstat 的常用命令，是本节最直接的操作依据：

```bash
# 合并显示各列
jstat -gc <pid> 1000

# 只看 GC 相关的列（更清爽）
jstat -gcutil <pid> 1000
```

jstat 输出的关键列：

| 列 | 含义 | 怎么看 |
| --- | --- | --- |
| S0C / S1C / EC | 两个 Survivor 与 Eden 的容量（KB） | 反映新生代大小配置 |
| OU / OC | 老年代使用量 / 容量 | 持续增长 → 老年代泄漏 |
| YGC / YGCT | Young GC 次数 / 总耗时 | 频率过高 → 分配速率太快 |
| FGC / FGCT | Full GC 次数 / 总耗时 | **只要有就要查原因** |
| GCCS | GC 后使用量 | 与 OU 对比可判断回收是否有效 |

《JVM 调优工具》特别强调用 `jstat -gcutil` 时关注各列的**比率**（如 O、YGC 的变化趋势），比看绝对值更能反映问题。

**jstack 与线程状态**

《二哥的 JVM 进阶之路》与《深入浅出 Java 多线程》都涉及线程 dump 的分析。jstack 输出中每个线程都带状态标记，排查时的关注点：

- `BLOCKED` → 死锁或锁竞争（看 `-Deadlock` 段落）
- `WAITING (on object monitor)` → 等待释放锁
- `RUNNABLE` 且 CPU 占用高 → 用 `top -H -p <pid>` 找到线程 ID，再 `jstack | grep <tid>` 定位
- `TIMED_WAITING` 且在 `Thread.sleep` → 正常的定时任务

**死锁的四个必要条件**

《面试题-04-并发编程面试题》把「什么是线程死锁，形成死锁的四个必要条件」列为高频题：

1. 互斥条件
2. 不可剥夺条件
3. 持有并等待条件
4. 循环等待条件

打破任一条件即可避免死锁，实践中最常用的是「**按固定顺序加锁**」来破坏循环等待条件。

**内存泄漏与内存溢出的区别**

《面试题-08-Java虚拟机(JVM)面试题》与《面渣逆袭 JVM》都明确区分了这两个概念：

- **内存泄漏**：内存占用持续增长，GC 无法回收，最终 OOM。是**现象**
- **内存溢出（OOM）**：分配内存时超出可用上限。是**结果**

典型泄漏源（知识库中《面渣逆袭 JVM》与《面渣逆袭 Java 集合框架篇》都提到）：

- 静态集合持有对象引用（最常见）
- 监听器注册后未注销
- 线程池中的 ThreadLocal 未 remove
- 连接未关闭（数据库、文件流）

## 实战提示

一套标准的线上排查流程：

```bash
# 1. 确认内存趋势
jstat -gcutil <pid> 1000

# 2. 抓线程栈（CPU 高时抓 3 次，间隔 5 秒，对比）
jstack <pid> > thread1.txt

# 3. 抓堆快照（OOM 前抓，或用 jcmd 更安全）
jcmd <pid> GC.heap_dump /tmp/heap.hprof

# 4. 查 GC 日志
jcmd <pid> GC.heap_info
```

MAT 中打开 hprof 后，第一步看 **Leak Suspects Report**，第二步看 **Dominator Tree** 按 Retained Heap 排序—— dominator 最大的那个对象就是泄漏源头。第三步用 **Path to GC Roots** 找出它为什么没被回收。

排查 CPU 飙高则是另一条路径：`top -H -p <pid>` 拿到占用最高的线程 TID（十进制转十六进制）→ `jstack` 里 grep 该 nid → 找到具体方法栈。

**关于 Arthas**：知识库中《二哥的 JVM 进阶之路》的《Java多线程开发实战手册》提到过它。相比命令行工具，Arthas 的 `dashboard`、`thread -n 3`、`trace`、`watch` 让排查过程无需重启进程，在生产环境更适合；但它自身有性能开销，压测环境需谨慎开启。
' WHERE slug = 'jvm-tuning-tools';

-- bytecode
UPDATE lesson SET content = '## 本节要点

Java 的「一次编译，到处运行」靠的是**字节码**：源码编译成与平台无关的 class 文件，由各平台的 JVM 解释或 JIT 编译成机器码。class 文件是一套严格定义的二进制格式，方法执行的核心单位是**栈帧**。

## 核心概念

- **字节码（Bytecode）**：中间指令集，与平台无关，是 JVM 的输入。
- **class 文件结构**：以 u1/u2/u4/u8 描述的二进制格式，依次是魔数、版本号、常量池、访问标志、类/接口定义、字段表、方法表、属性表。
- **常量池**：class 文件的「资源仓库」，存放字面量与符号引用，是索引化的（类似数组而非 Map）。
- **方法表中的 Code 属性**：局部变量表、操作数栈、异常表、LineNumberTable 等。
- **栈帧（Stack Frame）**：每次方法调用创建，包含局部变量表、操作数栈、动态链接、方法引用、返回地址。
- **操作数栈**：JVM 的计算核心，字节码指令直接操作它。
- **执行引擎**：解释器（逐条解释，慢）+ JIT（热点代码编译成本地代码，快）。
- **即时编译器**：C1（Client，编译快、优化少）+ C2（Server，优化深），分层编译按调用次数与热度选择。

## 关键代码

```java
// 方法调用对应的栈帧压栈与出栈
void caller() {
    int a = add(1, 2);   // 压入 caller 栈帧 → 调用 add（新建栈帧）→ 返回后弹出
    System.out.println(a);
}

int add(int x, int y) {
    // add 的栈帧：局部变量表含 x、y；操作数栈存放运算中间结果
    return x + y;
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为"一次编译到处运行"是 JVM 逐条解释执行，实际热点代码会被 JIT 编译成本地代码
- 混淆「栈帧」与「线程栈」——线程栈是栈帧的容器
- 认为局部变量表在方法执行完还能访问，它的作用域仅限当前栈帧
- 以为 `int` 参数传的是值、`String` 参数传的是引用，实际所有参数都是值传递

## 动手练习

用 `javap -c -v` 反编译一个方法，逐行对照字节码与栈帧中局部变量表、操作数栈的变化。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《doocs-jvm》《深入理解 Java 虚拟机（第 3 版）》《二哥的 JVM 进阶之路》对本节有系统覆盖。

**class 文件结构的字段宽度**

《doocs-jvm》给出了「u2、u4、u8 分别代表……」的说明，这是读懂 class 文件格式的必备前提：

| 类型 | 字节 | 典型用途 |
| --- | --- | --- |
| u1 | 1 | 魔数部分、access_flags |
| u2 | 2 | minor/major 版本号、常量池数量、字段/方法数量、属性长度 |
| u4 | 4 | 常量池索引、字段名索引、属性名索引 |
| u8 | 8 | CONSTANT_Long、CONSTANT_Double 的实际值 |

class 文件的整体布局（依据《doocs-jvm》）：

```
ClassFile {
    u4 magic;                 // 0xCAFEBABE
    u2 minor_version, major_version;
    u2 constant_pool_count;
    cp_info constant_pool[];  // 常量池，第 1 项有效
    u2 access_flags;
    u2 this_class, super_class;
    u2 interfaces_count; u2 interfaces[];
    u2 fields_count; field_info fields[];
    u2 methods_count; method_info methods[];
    u2 attributes_count; attribute_info attributes[];
}
```

**常量池是 class 文件的核心**

《doocs-jvm》指出常量池里存了两类东西：**字面量**（如字符串、整数常量）与**符号引用**（字段/方法/类的符号引用）。符号引用在解析阶段被替换为直接引用，这正是「动态链接」的含义——运行时才知道要调用哪个方法的具体地址。

**字节码指令的分类**

《深入理解 Java 虚拟机（第 3 版）》第 6 章专门讲字节码指令，可归纳为 8 类：

- 加载与存储：`iload`、`aload`、`istore`、`astore`
- 运算：`iadd`、`isub`、`imul`、`idiv`、`irem`
- 类型转换：`i2l`、`i2d`、`d2i`
- 对象与数组：`new`、`getfield`、`putfield`、`newarray`、`arraylength`
- 控制转移：`ifeq`、`if_icmpeq`、`goto`、`tableswitch`、`lookupswitch`
- 返回：`ireturn`、`areturn`、`return`
- 方法调用：`invokevirtual`、`invokestatic`、`invokeinterface`、`invokedynamic`
- 异常处理：`athrow`、`catch`（通过异常表实现）

其中 `tableswitch` 与 `lookupswitch` 是 `switch` 编译后的两种形式：前者用于 case 连续、后者用于 case 稀疏。

**invokedynamic 与 Lambda**

知识库中《深入浅出 Java + 23 种设计模式》与《二哥的 Java 进阶之路》都在讲 Lambda 与函数式接口时提到 `invokedynamic`。它是 JDK 7 引入的指令，用于在运行期决定调用哪个方法——Lambda 表达式正是靠它在运行期生成实现类并绑定方法引用，这是「Lambda 不产生额外类文件」的技术原因。

**栈帧的结构**

《深入理解 Java 虚拟机（第 3 版）》给出的栈帧结构是：

| 局部 | 说明 |
| --- | --- |
| 局部变量表 | 存储方法参数与局部变量，以 slot 为单位，`long`/`double` 占 2 个 slot |
| 操作数栈 | 字节码指令的工作区，最大深度由 `max_stack` 指定 |
| 动态链接 | 指向运行时常量池的方法引用 |
| 方法引用 | 指向方法本身 |
| 返回地址 | 恢复调用者的 pc |

局部变量表中的 slot 复用是常见考点：一个方法内多个局部变量可以共用同一个 slot（前提是作用域不重叠），这让 `javap -l` 输出的 LocalVariableTable 看起来"槽位"比变量少。

## 实战提示

看懂字节码的实用场景：

```bash
# 反编译方法字节码与局部变量表
javap -c -l -p MyClass.class

# 只看某个方法
javap -c MyClass.class | sed -n ''/void foo()/,/^$/p''
```

最常用来解决三类问题：

1. **确认泛型擦除的实际结果**——`List<String>` 与 `List<Integer>` 在字节码层面签名相同
2. **理解 lambda 的实现**——看 `invokedynamic` 的 bootstrap 方法指向哪个 `LambdaMetafactory`
3. **验证编译器优化**——如字符串拼接在 `invokedynamic` 下会被编译成 `StringConcatFactory.makeConcatWithConstants`，比老版本的 StringBuilder 拼接更高效

另外注意：`javap` 显示的是**逻辑结构**，而 `javap -v` 加上 `Code` 属性的字节码反汇编才能看到真实指令序列。配合 `-l` 看 LocalVariableTable，才能把指令与源码变量一一对应。
' WHERE slug = 'bytecode';

-- project-memory-leak
UPDATE lesson SET content = '## 本节要点

内存泄漏的本质是：**本该被回收的对象仍然可达**。排查要回答两个问题——哪些对象没被回收（dump 分析），以及为什么没被回收（GC Roots 路径分析）。常见的元凶是静态集合、监听器、ThreadLocal 与未关闭的连接。

## 核心概念

- **内存泄漏 vs 内存溢出**：泄漏是「占用持续增长且无法回收」的现象，溢出（OOM）是「申请内存超出上限」的结果。
- **静态集合**：最常见的泄漏源。`static` 集合随类加载器存活，只要类不被卸载，元素就永远可达。
- **ThreadLocal**：线程池中的线程复用，ThreadLocalMap 里的 value 只有 remove 才会清。
- **监听器/回调未注销**：注册进长生命周期对象（容器、静态集合）后不反注册。
- **未关闭的连接**：JDBC Connection、文件流、Socket 占着堆外内存与 native 资源。
- **类加载器泄漏**：动态生成的类无法卸载（元空间泄漏），Tomcat 热部署常见。
- **dump 分析三板斧**：Leak Suspects → Dominator Tree → Path to GC Roots。

## 关键代码

```java
// 泄漏复现：静态集合持有对象引用，GC 无法回收
public class LeakDemo {
    // 静态集合 —— 类加载器级别存活，里面的东西永远可达
    private static final List<Object> CACHE = new ArrayList<>();

    public static void leak() {
        for (int i = 0; i < 10000; i++) {
            CACHE.add(new byte[1024 * 1024]);   // 每次 1MB
        }
    }
}

// 正确写法：用 WeakReference 观察回收（配合 -XX:+PrintReferenceGC）
WeakReference<byte[]> ref = new WeakReference<>(new byte[1024 * 1024]);
System.gc();
Thread.sleep(100);
System.out.println(ref.get() == null ? "已回收" : "仍可达");
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 OOM 就一定是堆太小，其实元空间溢出、线程创建失败都与堆大小无关
- 靠"重启就好了"掩盖问题，泄漏源没找到下次还会复发
- 误用 `System.gc()` 作为"解决方案"，它只是提示，还会带来额外停顿
- 认为 WeakReference 能解决所有泄漏，它只解决"引用关系"造成的泄漏，解决不了"业务上仍然需要"的强引用

## 动手练习

写一个模拟静态集合泄漏的程序，用 `jcmd <pid> GC.heap_dump` 抓快照，在 MAT 中找出 dominator 最大的对象并定位其 GC Root 路径。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭 JVM》《深入理解 Java 虚拟机（第 3 版）》《面试题-08-Java虚拟机(JVM)面试题》以及《Java多线程开发最佳实践手册》对本节给出了完整的排查视角。

**内存泄漏与内存溢出的关系**

《面试题-08-Java虚拟机(JVM)面试题》把这两个问题放在一起对比：

- 「内存溢出异常」——「Java 会存在内存泄漏吗？请简单描述」
- 「Java 会存在内存泄漏吗？」的答案：**内存泄漏是指内存空间被占满却无法回收**，持续累积最终导致 OOM

知识库中列举的典型泄漏场景：

1. **静态集合**：往静态 List/Map 里塞对象且不清理
2. **监听器**：注册了监听器但没有反注册
3. **连接未关闭**：数据库连接、流、Socket
4. **ThreadLocal**：线程池复用线程时 value 残留
5. **缓存无淘汰策略**：Map 无限增长

**类型卸载与类加载器泄漏**

《doocs-jvm》指出方法区回收的目标之一是**对类型的卸载**，而卸载需要三个条件同时满足：类的所有实例都被回收、加载它的 ClassLoader 被回收、Class 对象没被引用。

这条链在容器环境里格外重要——《二哥的 JVM 进阶之路》与《深入浅出 Java 多线程》都提到自定义类加载器的生命周期管理。Tomcat 中每个 Web 应用有独立 ClassLoader，若应用中有大量动态代理、脚本引擎或频繁热部署，ClassLoader 无法被回收 => 对应的元空间也无法回收 => `OutOfMemoryError: Metaspace`。

**并发场景下的泄漏源**

《Java多线程开发最佳实践手册》覆盖了线程创建与生命周期管理、同步机制、JUC 工具、线程池配置优化、CompletableFuture 异步编程等 30 多个实战示例，其中线程池相关的实践正是泄漏高发区：

```java
// 错误：ThreadLocal 未 remove，线程复用导致 value 残留
private static final ThreadLocal<UserContext> CTX = new ThreadLocal<>();
// ... 使用 CTX.set(user)
executor.submit(() -> {
    UserContext ctx = CTX.get();   // 拿到的是上一个任务残留的！
});

// 正确：finally 中清理
executor.submit(() -> {
    try {
        CTX.set(user);
        // 业务逻辑
    } finally {
        CTX.remove();
    }
});
```

**排查工具链**

《JVM 调优工具》与《二哥的 JVM 进阶之路》覆盖的工具正好构成本节的实操路径：

- `jstat -gcutil <pid> 1000` — 观察老年代是否持续增长
- `jcmd <pid> GC.heap_dump /path/heap.hprof` — 抓堆快照（比 `jmap` 更安全）
- `jstack <pid>` — 看线程是否卡在某个对象上

**软引用、弱引用与缓存**

《面渣逆袭Java并发编程》与《面渣逆袭 Java 集合框架篇》在讲缓存实现时对比了三种引用：

| 引用 | 回收时机 | 典型用途 |
| --- | --- | --- |
| 强引用 | 永不回收 | 普通对象 |
| 软引用 | 内存不足时回收 | 内存敏感的数据缓存 |
| 弱引用 | 下次 GC 必定回收 | 规范化的 canonical 映射 |
| 虚引用 | 不决定生命周期 | 堆外内存管理 |

做缓存时，若用强引用 + 无淘汰策略，就是一个必然会 OOM 的设计。

## 实战提示

一套可复用的排查流程：

```bash
# 1. 观察增长趋势（连续观察，确认是"持续增长"而非波动）
jstat -gcutil <pid> 1000

# 2. 确认老年代在涨
jstat -gc <pid> 1000 | awk ''{print "OU="$9" OC="$10" YGC="$13" FGC="$15}''

# 3. 抓快照（在 OOM 前抓，或配 -XX:+HeapDumpOnOutOfMemoryError 自动抓）
java -XX:+HeapDumpOnOutOfMemoryError -jar app.jar
# 产出 java_pid<pid>.hprof
```

MAT 中：`Leak Suspects Report` 先看自动分析 → `Dominator Tree` 按 Retained Heap 排序找大头 → 右键选 `Path to GC Roots > exclude weak references`，看它被谁引用着。

**关键判据**：如果 dominator 最大的对象是 `HashMap$Node[]` 或 `byte[]`，去查是不是有静态集合或无界缓存；如果看到大量 `Class` 对象实例，怀疑类加载器泄漏或动态代理滥用；如果 dominator 是 `ThreadLocal$ThreadLocalMap`，查 `remove()` 是否遗漏。

**预防比排查更重要**：能用自动装配管理的对象不要手写 new；缓存一定要有容量上界与淘汰策略；ThreadLocal 必须在 `finally` 里 remove；所有资源用 try-with-resources。
' WHERE slug = 'project-memory-leak';

-- thread-basics
UPDATE lesson SET content = '## 本节要点

线程是 CPU 调度的最小单位。Java 提供四种创建方式，但推荐 `Runnable` 或线程池。线程有六种状态，转换由 `Thread` 的方法驱动。并发编程要守住三个要素：**原子性、可见性、有序性**。

## 核心概念

- **并发 vs 并行**：并发是「同一时刻多个任务交替推进」，并行是「同一时刻多个任务真正同时执行」。单核靠时间片轮转实现并发，多核才能真正并行。
- **线程 vs 进程**：进程是资源分配的基本单位，线程是 CPU 调度的基本单位。同一进程的线程共享堆、方法区，但各自持有栈和程序计数器。
- **四种创建方式**：`Thread` 子类、`Runnable`、`Callable`+`FutureTask`、`线程池`。后两者可返回结果、可抛异常。
- **六种状态**：NEW、RUNNABLE、BLOCKED、WAITING、TIMED_WAITING、TERMINATED。注意 RUNNABLE 同时包含 OS 层面的就绪与运行两种状态。
- **上下文切换**：线程从 CPU 上换下再换上，代价与栈深度成正比。
- **原子性**：操作不可被中断。`i++` 实际是「读—改—写」三步，不是原子的。
- **可见性**：一个线程的修改对其他线程可见。需靠 `volatile` / 同步机制保证。
- **有序性**：程序执行顺序不因编译器/CPU 重排而改变。
- **守护线程**：不影响 JVM 退出（GC 线程、IO 线程）。用户线程结束即触发 JVM 退出。

## 关键代码

```java
// 方式一：Runnable（推荐，无返回值但无继承耦合）
new Thread(() -> System.out.println("hello")).start();

// 方式二：Callable + FutureTask（有返回值、可抛受检异常）
FutureTask<String> task = new FutureTask<>(() -> "result");
new Thread(task).start();
System.out.println(task.get());   // 阻塞等待结果

// 线程状态
Thread t = new Thread(() -> { });
System.out.println(t.getState()); // NEW
t.start();
Thread.sleep(100);
// t.getState() 此时通常是 RUNNABLE 或 TIMED_WAITING

// 守护线程
Thread daemon = new Thread(() -> {
    try {
        while (true) Thread.sleep(1000);
    } catch (InterruptedException ignored) { }
});
daemon.setDaemon(true);
daemon.start();
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 Runnable 比 Callable"低效"，实际只是不能返回值与抛受检异常
- 以为调用 `t.start()` 两次会报异常，它会抛 `IllegalThreadStateException`
- 把「线程.sleep」当作让出 CPU 的正确手段，它只是让当前线程进入 TIMED_WAITING
- 以为线程数越多越快，上下文切换的开销可能适得其反

## 动手练习

用 `Thread.getState()` 打印一个线程从创建到结束的全部状态转换，观察线程在 WAITING 与 RUNNABLE 之间切换。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭Java并发编程》《面试题-04-并发编程面试题》《深入浅出 Java 多线程-RedSpider》《Java多线程开发实战手册》《由浅入深Java并发》对本节覆盖非常完整。

**并发编程三要素**

《面试题-04-并发编程面试题》开篇即列出「并发编程三要素是什么？」：

1. **原子性**：一个操作不可被中断，要么全执行要么全不执行
2. **可见性**：一个线程修改了变量，其他线程能立即看到
3. **有序性**：程序的执行顺序不会被重排打乱

并在「在 Java 程序中怎么保证多线程的运行安全？」中给出解法映射：原子性靠 CAS / 锁，可见性靠 `volatile` / 锁，有序性靠 `volatile` 的内存屏障。

**并发 vs 并行的图示**

《面渣逆袭Java并发编程》用一张图区分二者：并行是同一时刻两个线程都在执行（需要两个 CPU）；并发是同一时刻只有一个在执行，但一段时间内两个都执行过。**并发的实现依赖于 CPU 切换线程，因为切换时间特别短，用户基本无感知。**

**死锁的四个必要条件**

同一份资料详细列出了死锁条件与规避方式：

1. 互斥条件
2. 不可剥夺条件
3. 持有并等待条件
4. 循环等待条件

「如何避免线程死锁」的工程做法：**破坏循环等待条件**——所有线程按全局固定顺序获取锁。

**创建线程的四种方式与 Runnable / Callable 的区别**

《面试题-04》对比了两者：Runnable 没有返回值、不能抛受检异常；Callable 有泛型返回值、可以抛异常、还能通过 FutureTask 拿到结果。实践中 `Runnable` 更常用（配合线程池），需要结果时才用 `Callable`。

**Java 线程与操作系统线程的关系**

《深入理解高并发编程：核心原理与案例实战》的思维导图第 1 章第 1.4 节专门讲「Java 线程与操作系统线程的关系」，同时覆盖了：

- 冯诺依曼计算机模型与 CPU 架构
- 单核 CPU 的不足、多核 CPU 架构、多 CPU 架构
- 用户级线程、内核级线程、混合级线程三种模型

Java 采用的是**一对一映射**（一个 Java 线程对应一个 OS 线程），因此线程创建、销毁成本较高——这正是线程池存在的根本原因。

**线程状态与线程优先级**

《深入浅出 Java 多线程-RedSpider》的目录显示其"基础篇"第 3 章讲线程组与线程优先级，第 4 章讲「Java 线程的状态及主要转化方法」，第 5 章讲线程间通信。它把线程状态分为 6 种：

| 状态 | 含义 |
| --- | --- |
| NEW | 尚未启动 |
| RUNNABLE | 在 JVM 中正在执行（含 OS 就绪） |
| BLOCKED | 等待获取 synchronized 锁 |
| WAITING | 无限期等待（Object.wait、Thread.join） |
| TIMED_WAITING | 限期等待（sleep、wait(timeout)） |
| TERMINATED | 已终止 |

**守护线程与用户线程**

同一份资料指出：守护线程是为辅助服务用户线程而存在的，其生命周期依附于用户线程，**用户线程结束，守护线程随之结束**。典型守护线程有垃圾回收线程、编译器线程等。

**查找高 CPU 线程的方法**

《面试题-04》还提到「如何在 Windows 和 Linux 上查找哪个线程 CPU 利用率最高？」，这在实战排查中非常有用：

```bash
# Linux：top -H 找出线程级 CPU 占用最高的 TID
top -H -p <pid>
# 转成十六进制后在 jstack 里匹配 nid
printf ''%x\n'' <tid>
jstack <pid> | grep -A 20 ''<nid>''
```

## 实战提示

线程数不是越多越好。经验公式：

- **CPU 密集型**（计算、加解密、压缩）：线程数 ≈ 核数 + 1
- **IO 密集型**（数据库、RPC、文件）：线程数 ≈ 核数 × (1 + 等待时间/计算时间)

《Java多线程开发实战手册》在"线程池配置优化"一节给出的思路正是如此：先压测确定基线，再按任务类型调整，而不是拍脑袋给一个 200。

另一个容易被忽略的细节：**不要在持锁期间调用可能阻塞或耗时长的操作**（如远程调用、打印日志）。这既是死锁的高发原因，也让锁的粒度白白变大。
' WHERE slug = 'thread-basics';

-- lock-mechanisms
UPDATE lesson SET content = '## 本节要点

`synchronized` 是 JVM 层面的monitor（管程），靠对象头里的锁状态标志实现锁升级；`ReentrantLock` 是 JUC 的显式锁，底层基于 AQS 的 CAS。两者都可重入，区别在于后者支持**公平锁、可中断、超时获取、多条件变量**。

## 核心概念

- **monitorenter / monitorexit**：字节码指令，对应同步代码块与同步方法。
- **锁状态标志**：对象头 Mark Word 中的几位，标记无锁 → 偏向锁 → 轻量级锁 → 重量级锁。
- **锁升级（膨胀）**：无锁 → 偏向锁（已废弃）→ 轻量级锁（CAS 自旋）→ 重量级锁（操作系统互斥锁）。**只能升级不能降级**。
- **轻量级锁**：用 CAS + 自旋实现，不涉及内核态切换，适合「多线程交替执行」的低竞争场景。
- **重量级锁**：竞争激烈时膨胀为 monitor，线程进入 BLOCKED 状态，由 OS 负责调度。
- **AQS（AbstractQueuedSynchronizer）**：JUC 同步器的骨架，用一个 volatile int state 表示同步状态 + 一个 CLH 变体的双向队列管理等待线程。
- **CAS（Compare And Swap）**：无锁并发的基础，`compareAndSet` 原子更新。
- **公平锁 vs 非公平锁**：公平锁按队列 FIFO 获取锁，非公平锁允许刚到位的线程"插队"（tryAcquire 的实现差异）。
- **可重入**：同一线程可重复获取同一把锁（重入计数）。
- **Condition**：每个 Lock 可new 出多个条件队列，比 `Object.wait/notifyAll` 更精确。

## 关键代码

```java
// synchronized：同步代码块（锁对象）与同步方法（锁 this）
Object lock = new Object();
synchronized (lock) {
    // 临界区
}

public synchronized void method() {
    // 锁的是 this
}

// ReentrantLock：手动加解锁，必须放在 finally 里
private final ReentrantLock lock = new ReentrantLock();

void safeMethod() {
    lock.lock();
    try {
        // 临界区
    } finally {
        lock.unlock();     // 忘记 unlock 会导致死锁
    }
}

// 公平锁 + 可中断获取
private final ReentrantLock fair = new ReentrantLock(true);
try {
    if (fair.tryLock(1, TimeUnit.SECONDS)) {
        try { /* 业务 */ } finally { fair.unlock(); }
    }
} catch (InterruptedException e) {
    Thread.currentThread().interrupt();   // 恢复中断标志
}

// 多条件变量：队列非空 / 队列非满
private final Condition notEmpty = lock.newCondition();
private final Condition notFull = lock.newCondition();
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 `synchronized` 一定会膨胀到重量级锁——低竞争下只用轻量级锁，几乎无开销
- 认为 `ReentrantLock` 一定比 `synchronized` 快——性能取决于竞争程度
- 忘记 `unlock()` 或把 `unlock()` 写在 `try` 块内
- 认为 `wait/notify` 必须配合 `synchronized`，其实必须配合**同一个监视器对象**
- 在 `synchronized` 块里调用外部方法，怕「业务方也加锁」导致死锁

## 动手练习

用 `jstack` 观察一个因锁竞争进入 BLOCKED 状态的线程栈，分析它卡在哪个 monitor 上。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《深入理解高并发编程（第 2 版）》《二哥的并发编程进阶之路》《极致经典（卷 1/2/3）：Java 高并发核心编程》《面渣逆袭Java并发编程》对本节有深入覆盖。

**synchronized 的锁对象**

《深入理解 JVM 核心技术》给出一条关键规则：「普通同步方法，锁是当前实例对象锁」。完整的锁对象表：

| 同步形式 | 锁对象 |
| --- | --- |
| 同步实例方法 | `this` |
| 同步静态方法 | `Class` 对象（`Class.forName("X").class`） |
| 同步代码块 | `synchronized(...)` 括号里指定的对象 |
| 同步方法（可重入） | 同一线程可再次进入，计数 +1 |

**锁升级路径**

知识库中《二哥的 JVM 进阶之路》与《深入浅出 Java 多线程》都覆盖了锁升级。要点：

- **无锁 → 偏向锁**：只有一个线程访问时，把线程 ID 写入 Mark Word，后续该线程访问无需 CAS。JDK 15 起偏向锁被废弃（JEP 374），JDK 18 彻底移除。
- **偏向锁 → 轻量级锁**：出现第二个线程访问时，撤销偏向锁，升级为轻量级锁。
- **轻量级锁 → 重量级锁**：自旋超过阈值（默认 10 次 / 20 次自旋，JDK 6 后自适应）仍获取不到，则膨胀为重量级锁。

**自适应的自旋**：JDK 6 引入。自旋次数由「最近一次成功获取锁的线程是否很快释放」决定，避免「刚释放就要等线程切换」的开销。

**AQS 与两种锁的实现差异**

《深入理解高并发编程（第 2 版）》与《二哥的并发编程进阶之路》都指出：「锁、非公平锁底层采用 AQS 实现」。AQS 的核心结构：

```java
private volatile int state;                 // 同步状态
private volatile Node head, tail;           // CLH 双向队列
```

`ReentrantLock` 的两种获取方式正是公平性的分水岭：

| 方法 | 行为 |
| --- | --- |
| `lock()` | 公平锁：先 `hasQueuedPredecessors()` 判断队列中是否有前驱；非公平锁：直接 `tryAcquire` 抢占 |
| `tryLock()` | 两种锁都是直接尝试一次，失败立即返回 false，不排队 |

非公平锁的"插队"就发生在 `tryAcquire` 里：即使队列里有人在等，只要当前线程能 CAS 成功就立刻拿到锁。**默认使用非公平锁**，因为公平锁的线程切换开销大，吞吐明显更低。

**ReentrantLock 的额外能力**

知识库中《面渣逆袭Java并发编程》对比了 `synchronized` 与 `ReentrantLock`：

| 能力 | synchronized | ReentrantLock |
| --- | --- | --- |
| 公平性 | 只能非公平 | 可选 |
| 可中断获取 | 否 | `lockInterruptibly()` |
| 超时获取 | 否 | `tryLock(timeout)` |
| 多条件变量 | 否（只有 wait/notifyAll） | `newCondition()` 多个 |
| 必须在 finally 解锁 | 自动 | 手动 |

**wait / notifyAll 与 Condition**

《深入浅出 Java 多线程-RedSpider》"基础篇"第 5 章讲线程间通信。`Object.wait()` 的三个约束：

1. 必须在 `synchronized` 块中调用
2. 必须持有该监视器的锁
3. 唤醒方必须是**同一个监视器**上的 `notify`/`notifyAll`

`Condition` 是 AQS 提供的替代方案，每个条件有独立的等待队列，唤醒更精准。典型用法是阻塞队列：

```java
// 生产者：队列满则等待 notFull
while (queue.size() == capacity) notFull.await();
// 消费者：队列空则等待 notEmpty
while (queue.isEmpty()) notEmpty.await();
```

**避免死锁的工程实践**

《面试题-04-并发编程面试题》给出的死锁四个必要条件中，最实用的是打破**循环等待条件**——全局固定加锁顺序：

```java
// 所有地方都按 userId -> orderId 的顺序加锁，杜绝交叉
synchronized (userMap.get(userId)) {
    synchronized (orderMap.get(orderId)) {
        // ...
    }
}
```

## 实战提示

选型建议：

| 场景 | 选择 |
| --- | --- |
| 简单同步、临界区短 | `synchronized`（JVM 优化后零额外开销） |
| 需要超时/中断/公平/多条件 | `ReentrantLock` |
| 单写多读、读远多于写 | `ReadWriteLock` |
| 无锁计数、状态机 | `AtomicInteger` / `LongAdder` |

排查锁问题的实用手段：

```bash
# 看哪些线程 BLOCKED
jstack <pid> | grep -B 5 -A 15 "BLOCKED"

# 看锁竞争情况（JDK 8+）
jcmd <pid> Thread.print -l
```

`synchronized` 锁在 JDK 15+ 已被**重新实现**（JEP 374 移除偏向锁），不再是「对象头写线程 ID」的老实现，而是用 **Lightweight Lock（-thin lock）** 在对象头上直接记录持锁线程，膨胀时再转成 monitor。这让无竞争场景下的同步开销降到接近于零。
' WHERE slug = 'lock-mechanisms';

-- thread-pool
UPDATE lesson SET content = '## 本节要点

线程池通过复用线程降低创建销毁开销，并用**队列 + 拒绝策略**应对任务超出处理能力的情况。`ThreadPoolExecutor` 的四个关键参数（核心数、最大数、空闲存活时间、工作队列）决定了它的全部行为。

## 核心概念

- **核心线程数（corePoolSize）**：池中常驻线程数，任务优先由核心线程处理。
- **最大线程数（maximumPoolSize）**：队列满后可创建的上限。
- **空闲存活时间（keepAliveTime）**：非核心线程空闲多久后回收。
- **工作队列（workQueue）**：核心线程忙时，任务在此排队。
- **拒绝策略（rejectionHandler）**：线程数达上限且队列满时怎么办。
- **执行流程**：核心线程 → 队列 → 扩到最大线程 → 拒绝策略。
- **四种拒绝策略**：AbortPolicy（抛异常）、CallerRunsPolicy（调用方线程执行）、DiscardPolicy（丢弃）、DiscardOldestPolicy（丢最老的）。
- **为什么不建议用 Executors**：newFixedThreadPool / newSingleThreadExecutor 用无界队列（OOM 风险）；newCachedThreadPool 用 SynchronousQueue 且最大线程数无限（同样 OOM 风险）。
- **线程池状态**：RUNNING → SHUTDOWN → STOP → TIDYING → TERMINATED。
- **任务类型**：Runnable 无返回值，Callable 有返回值可抛异常（需配合 FutureTask）。

## 关键代码

```java
// 推荐显式 new ThreadPoolExecutor，避免 Executors 的无界队列问题
ThreadPoolExecutor pool = new ThreadPoolExecutor(
        4,                      // 核心线程数
        8,                      // 最大线程数
        60L, TimeUnit.SECONDS,  // 空闲存活时间
        new ArrayBlockingQueue<>(200),   // 有界队列
        new ThreadPoolExecutor.CallerRunsPolicy()  // 背压：调用方自己跑
);

pool.execute(() -> System.out.println("task"));

// 有返回值的任务
Future<Integer> f = pool.submit(() -> 42);
System.out.println(f.get());

// 优雅关闭
pool.shutdown();                  // 不再接收新任务，跑完存量后终止
// pool.shutdownNow();           // 立即中断
pool.awaitTermination(30, TimeUnit.SECONDS);

// 线程池中的 ThreadLocal 必须清理
pool.execute(() -> {
    try {
        CTX.set(user);
        // 业务
    } finally {
        CTX.remove();            // 线程会被复用，不 remove 会串数据
    }
});
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 用 `Executors.newFixedThreadPool` 图省事，无界队列导致 OOM
- 认为线程池越大吞吐越高，忽略了上下文切换与内存开销
- 用 `shutdownNow()` 粗暴中断，任务里的资源没机会清理
- 忘了 `execute` 与 `submit` 的差别：`execute` 抛出的异常由线程的 UncaughtExceptionHandler 处理，`submit` 的异常被吞进 Future 里

## 动手练习

用自定义 ThreadPoolExecutor 模拟任务队列打满，观察 CallerRunsPolicy 下调用方线程被迫执行任务的效果。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《深入浅出 Java 多线程-RedSpider》《Java多线程开发最佳实践手册》《二哥的并发编程进阶之路》《深入理解高并发编程（第 2 版）》以及《面渣逆袭Java并发编程》对本节覆盖完整。

**线程池的复用机制**

《二哥的并发编程进阶之路》指出，线程池的核心是「池中的空闲线程异步提交任务」的复用模型。完整执行链路（与《深入浅出 Java 多线程》一致）：

1. 线程池为空 → 创建核心线程执行
2. 核心线程已满 → 任务进入工作队列
3. 队列满 → 创建非核心线程（直到 maximumPoolSize）
4. 线程数达上限且队列满 → 执行拒绝策略

《深入理解 JVM 核心技术》提到一个设计要点：「丢弃任务可重用固定线程数的线程池」——这正是 `CallerRunsPolicy` 的思路：宁可让提交方自己跑，也不丢任务，从而把压力反传给上游。

**线程池参数的经验值**

《Java多线程开发最佳实践手册》的"线程池配置优化"章节给出了系统的建议：

- **CPU 密集型**：N+1（N 为核数），因为线程大部分时间在计算，额外一个用于处理突发
- **IO 密集型**：N × (1 + WT/CT)，WT 为等待时间，CT 为计算时间
- 队列容量：不宜过大。队列越大，任务的实际延迟越长（排在第 N 个位置的任务要等前面全部完成）
- `keepAliveTime`：非核心线程的回收时间，一般 30s–60s

**RejectedExecutionHandler 的四种策略**

知识库中《深入浅出 Java 多线程》列出了完整的策略表：

| 策略 | 行为 | 适用场景 |
| --- | --- | --- |
| AbortPolicy | 抛 `RejectedExecutionException` | 需要感知拒绝并快速失败 |
| CallerRunsPolicy | 由提交任务的线程执行 | **背压首选**，天然限流 |
| DiscardPolicy | 静默丢弃 | 可丢失的任务（如埋点） |
| DiscardOldestPolicy | 丢弃队列头部最老的，重试入队 | 需要保新弃旧 |

**默认实现与推荐的差异**

《二哥的并发编程进阶之路》与《面渣逆袭Java并发编程》都提醒：`Executors` 工厂方法提供了便捷但有隐患的实现：

- `newFixedThreadPool(n)` / `newSingleThreadExecutor()` → `LinkedBlockingQueue` **无界队列**，任务堆积到 OOM
- `newCachedThreadPool()` → `SynchronousQueue` + `maximumPoolSize = Integer.MAX_VALUE`，线程数无限增长到 OOM
- `newScheduledThreadPool(n)` → 同样是无界的 `DelayedWorkQueue`

正解是显式 `new ThreadPoolExecutor(...)`，配上有界队列与 `CallerRunsPolicy`。

**线程池的状态机**

《深入浅出 Java 多线程》给出完整状态定义：

| 状态 | 说明 |
| --- | --- |
| RUNNING | 正常运行，接受新任务并处理队列任务 |
| SHUTDOWN | 不再接受新任务，继续处理队列中已有任务 |
| STOP | 不再接受新任务，中断正在执行的任务，清空队列 |
| TIDYING | 所有任务已终止，等待线程数归零 |
| TERMINATED | 线程池彻底关闭 |

`shutdown()` 与 `shutdownNow()` 的区别正对应 SHUTDOWN 与 STOP。

**JUC 的同步工具**

《Java多线程开发最佳实践手册》还覆盖了常用同步器，它们常常比 `synchronized` 更贴合场景：

- `CountDownLatch`：一个或多个线程等待其他线程完成（适合并行任务汇合）
- `CyclicBarrier`：一组线程互相等待（适合分阶段计算）
- `Semaphore`：通过许可数限制并发量（适合限流）
- `Phaser`：可动态注册参与者的分阶段屏障

## 实战提示

**给线程池加监控**（生产必备）：

```java
// 简易实现：继承 ThreadPoolExecutor 暴露统计信息
public class MonitoredPool extends ThreadPoolExecutor {
    public MonitoredPool(int core, int max, long keepAlive, TimeUnit unit,
                          BlockingQueue<Runnable> queue) {
        super(core, max, keepAlive, unit, queue);
    }
    // 定时调用 getActiveCount() / getQueue().size() / getCompletedTaskCount()
// 活跃数接近上限 + 队列堆积 => 需要扩容或限流
```

**判断线程池是否该扩**：队列长期非空 + 活跃线程数打满 => 吞吐已到瓶颈；队列长期为空 + 活跃数远低于核心数 => 核心数设大了。

**最重要的实践**：**不要用 `Executors`**，永远显式 `new ThreadPoolExecutor` 并指定有界队列 + 明确的拒绝策略。同时记住：线程池里的任务如果持有 ThreadLocal、数据库连接、文件句柄，必须在任务内部用 try-finally 清理，否则线程复用会把资源泄漏到下一个任务。
' WHERE slug = 'thread-pool';

-- concurrent-collections
UPDATE lesson SET content = '## 本节要点

并发集合与原子类解决的是「集合在多线程下怎么用」的问题。`ConcurrentHashMap` 在 JDK 8 放弃分段锁，改用 **CAS + synchronized 锁单个桶**；`CopyOnWriteArrayList` 用写时复制换读性能；原子类靠 CAS 提供无锁的原子操作。

## 核心概念

- **ConcurrentHashMap（JDK 8+）**：数组 + Node链表/红黑树；读操作完全无锁（volatile 读），写操作 CAS 失败则锁住桶首节点。
- **分段锁（Segment）**：JDK 7 的方案，ConcurrentHashMap 内部分段，每段一把锁。JDK 8 废弃。
- **CopyOnWriteArrayList**：写时复制整个数组，读操作无锁。适合「读远多于写、集合不大」。
- **AtomicInteger / AtomicLong / AtomicReference**：基于 CAS 的原子操作，`incrementAndGet()` 比 `synchronized` 轻得多。
- **LongAdder / DoubleAdder**：分段累加，高并发下比 AtomicLong 强得多（Cell 分散热点）。
- **原子类的 ABA 问题**：CAS 的经典缺陷，靠 `AtomicStampedReference` 解决。
- **ConcurrentLinkedQueue**：基于 CAS 的无锁队列。
- **BlockingQueue**：ArrayBlockingQueue（数组、有界）、LinkedBlockingQueue（链表、可有界）、SynchronousQueue（零容量直传）、PriorityBlockingQueue、DelayQueue。
- **volatile 与原子性的区别**：volatile 保证可见性与有序性，但 `count++` 仍非原子。

## 关键代码

```java
// ConcurrentHashMap：读无锁，写锁桶
ConcurrentHashMap<String, Integer> map = new ConcurrentHashMap<>();
map.put("a", 1);
map.merge("a", 1, Integer::sum);       // 原子累加
map.computeIfAbsent("b", k -> 0);       // 原子初始化

// CopyOnWriteArrayList：写时复制
CopyOnWriteArrayList<String> cow = new CopyOnWriteArrayList<>();
cow.add("x");                          // 复制整个底层数组

// 原子类
AtomicInteger counter = new AtomicInteger();
counter.incrementAndGet();             // CAS 自旋
LongAdder adder = new LongAdder();     // 高并发计数更优
adder.increment();

// BlockingQueue：生产者消费者
BlockingQueue<Task> queue = new ArrayBlockingQueue<>(100);
queue.put(task);        // 满则阻塞
queue.take();           // 空则阻塞
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 `ConcurrentHashMap` 的 `get` 会加锁——它完全无锁
- 用 `Vector` / `Hashtable` 代替并发集合——它们靠同步整个方法，吞吐差很多
- 在高并发计数场景用 `AtomicLong` 而非 `LongAdder`
- 认为 `CopyOnWriteArrayList` 适合写多场景——每次写都复制整个数组
- 以为 `ConcurrentHashMap` 的 `size()` 是精确值——它是弱一致的遍历计数

## 动手练习

压测对比 `AtomicLong` 与 `LongAdder` 在 16 线程累加下的耗时差异，并用 `ConcurrentHashMap` 实现一个线程安全的计数器。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《二哥的 Java 进阶之路暗黑版》《面渣逆袭 Java 集合框架篇》《面试题-02-Java集合容器面试题》《Java编程思想第四版》《深入理解高并发编程（第 2 版）》对本节覆盖完整。

**ConcurrentHashMap 的结构演进**

《二哥的 Java 进阶之路》与《深入理解高并发编程（第 2 版）》都提到「转换为红黑树链表转换为红黑树过程」与「ConcurrentHashMap 扩容操作控制」。

JDK 7 → JDK 8 的变化：

| 维度 | JDK 7 | JDK 8 |
| --- | --- | --- |
| 结构 | Segment 数组 + HashEntry 数组 + 链表 | Node 数组 + 链表 / 红黑树 |
| 锁粒度 | 段级（Segment） | 桶级（锁链表头节点） |
| 并发度 | Segment 数量（默认 16） | 桶数量 |
| 扩容 | 段内扩容 | 协助扩容（helpTransfer） |

JDK 8 的关键改进在于**扩容期间其他线程可以协助搬迁**，以及链表长度 ≥ 8 且数组长度 ≥ 64 时转为红黑树，把最坏情况下的查找从 O(n) 降到 O(log n)。

**红黑树转换条件**

《面试题-02-Java集合容器面试题》与《二哥的 Java 进阶之路》给出了 HashMap 与 ConcurrentHashMap 共用的树化条件：

- 链表长度 ≥ 8（TREEIFY_THRESHOLD）
- 数组容量 ≥ 64（MIN_TREEIFY_CAPACITY），否则优先扩容

树化的意义在于：正常情况下哈希分布良好，链表很短；但**恶意构造的哈希碰撞**会让查找退化成 O(n)，树化可防止这一攻击。

**ConcurrentHashMap 的读为什么无锁**

《深入理解 JVM 核心技术》与《二哥的 Java 进阶之路》都强调：JDK 8 中 `get` 方法不加锁，依靠三个 volatile 变量的内存语义保证可见性：

- `table`：桶数组引用
- `Node.val`：节点值
- `Node.next`：链表下一个节点

写操作则是：空桶 → CAS 放入节点；非空桶 → `synchronized (f)` 锁住链表头节点，只锁一个桶而非整个数组。这比 JDK 7 的段级锁并发度更高。

**原子类与 CAS**

《深入理解高并发编程（第 2 版）》系统讲解了 CAS（Compare And Swap）与 ABA 问题：

```java
// CAS 语义：期望值等于实际值才更新，否则返回 false
atomicInteger.compareAndSet(5, 6);   // 期望当前是 5 才改成 6
```

ABA 问题：值从 A 变成 B 又变回 A，CAS 会误认为没变过。解法是加版本号：

```java
AtomicStampedReference<String> ref = new AtomicStampedReference<>("A", 0);
int[] stamp = new int[1];
ref.compareAndSet("A", "B", 0, stamp[0] + 1);   // 带版本戳
```

**LongAdder 为什么更快**

《二哥的并发编程进阶之路》与《面渣逆袭Java并发编程》都提到热点分散的思想：`AtomicLong` 的所有线程 CAS 同一个变量，CAS 失败就自旋重试，高并发下成为热点；`LongAdder` 把值分散到多个 `Cell` 上，各线程 CAS 自己的 Cell，读时再求和。

**CopyOnWriteArrayList 的适用边界**

《面渣逆袭 Java 集合框架篇》强调：写时复制的代价是每次写都 O(n) 拷贝数组 + O(n) 加锁。适合的场景是**集合小、读极多、几乎不写**（如监听器列表、配置白名单）。不适用于写频繁或元素很多的场景。

**BlockingQueue 的四种实现**

《深入浅出 Java 多线程》与《Java多线程开发最佳实践手册》覆盖了队列选型：

| 实现 | 结构 | 特点 |
| --- | --- | --- |
| ArrayBlockingQueue | 数组 | **有界**，一把锁，公平可选 |
| LinkedBlockingQueue | 双向链表 | 默认容量 `Integer.MAX_VALUE`（实际无界），读写分离两把锁，吞吐更高 |
| SynchronousQueue | 无内部存储 | 零容量直接交接，用于线程池移交任务 |
| PriorityBlockingQueue | 堆 | 无界，按优先级出队 |
| DelayQueue | 堆 + 延迟 | 到期才能取出，用于定时任务 |

**CopyOnWriteArraySet 与并发 Set**

《面试题-02-Java集合容器面试题》指出，JDK 5 之后提供的 `CopyOnWriteArraySet` 基于 `CopyOnWriteArrayList` 实现，迭代器是**快照式**的——迭代期间不抛 `ConcurrentModificationException`，但也不反映后续修改。

## 实战提示

选型速查：

| 需求 | 选择 |
| --- | --- |
| 高并发读写 KV | `ConcurrentHashMap` |
| 读极多写极少 | `CopyOnWriteArrayList` |
| 单计数器 | `AtomicLong`（低并发）/ `LongAdder`（高并发） |
| 生产者消费者 | `ArrayBlockingQueue`（有界可控） |
| 延时任务 | `DelayQueue` 或 `ScheduledExecutorService` |

**注意 `ConcurrentHashMap` 的三个坑**：

1. `size()` 是弱一致的（遍历计数），并发写入时返回值不精确
2. `keySet()` 的迭代器是弱一致的，不抛 CME，但也可能看不到后续修改
3. **不允许 null 键和值**——因为 `get` 返回 null 时无法区分「不存在」与「值就是 null」，这与 `HashMap` 不同

**批量操作别用 `putIfAbsent` 循环**：需要原子性时用 `compute` / `merge`，它们在桶级加锁下保证一致性：

```java
// 原子累加
map.merge(key, 1, Integer::sum);
// 条件初始化
map.computeIfAbsent(key, k -> new Value());
```
' WHERE slug = 'concurrent-collections';

-- completablefuture
UPDATE lesson SET content = '## 本节要点

`CompletableFuture` 是 Java 8 引入的异步编排工具，用**回调 + 依赖**的方式替代 `Future.get()` 的阻塞等待。它支持串行依赖、并行执行、异常兜底与超时控制。

## 核心概念

- **核心思想**：把「等待结果」变成「拿到结果后继续做什么」。任务完成即回调，不阻塞线程。
- **静态工厂**：`supplyAsync`（有返回值）、`runAsync`（无返回值）。
- **默认线程池**：`ForkJoinPool.commonPool()`，是 JVM 共享的公共池。**生产环境要显式指定业务线程池**。
- **串行依赖**：`thenApply`（转换）、`thenAccept`（消费）、`thenRun`（不关心结果）。
- **扁平化组合**：`thenCompose`（返回 CompletableFuture 时用它，避免嵌套 Future）。
- **并行 + 汇聚**：`allOf`（全部完成，返回 void）、`anyOf`（任一完成）。
- **异常处理**：`exceptionally`（只处理异常）、`handle`（无论成败都执行）、`whenComplete`（观察但不改变结果）。
- **超时控制**：`orTimeout`（超时抛 TimeoutException）、`completeOnTimeout`（超时给默认值）。
- **手动完成**：`complete` / `completeExceptionally`，用于「外部回调驱动」的场景。
- **注意**：`thenApply` 等方法在**上一步的线程**上执行；`thenApplyAsync` 在新线程（可指定 Executor）。

## 关键代码

```java
// 串行：查询 -> 转换 -> 消费
CompletableFuture.supplyAsync(() -> queryUser(id))
        .thenApply(User::getName)
        .thenAccept(name -> log.info("name={}", name))
        .exceptionally(ex -> {
            log.error("查询失败", ex);
            return null;
        });

// 扁平化：避免 Future<Future<T>> 嵌套
CompletableFuture.supplyAsync(() -> queryUser(id))
        .thenCompose(user -> queryOrders(user.getId()));

// 并行 + 汇聚
CompletableFuture<String> a = CompletableFuture.supplyAsync(() -> "A");
CompletableFuture<String> b = CompletableFuture.supplyAsync(() -> "B");
CompletableFuture.allOf(a, b).thenRun(() -> {
    System.out.println(a.join() + b.join());
});

// 异常处理：handle 能拿到异常也能拿到结果
CompletableFuture.supplyAsync(() -> mayFail())
        .handle((r, ex) -> ex != null ? "fallback" : r);

// 超时
CompletableFuture.supplyAsync(() -> slowCall())
        .orTimeout(3, TimeUnit.SECONDS)
        .exceptionally(ex -> "timeout");

// 显式指定线程池（生产必做）
ExecutorService bizPool = Executors.newFixedThreadPool(8);
CompletableFuture.supplyAsync(() -> heavyIo(), bizPool);
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 用 `CompletableFuture.supplyAsync` 不传 Executor，导致业务任务挤占 `ForkJoinPool.commonPool()`，与全局 `parallelStream` 抢资源
- 在 `thenApply` 里做耗时操作——它跑在上一个任务的线程上，会拖慢那个线程
- 以为 `exceptionally` 能捕获 `thenApply` 内部抛出的异常（可以，但 `handle` 语义更清晰）
- 忽略 `join()` 与 `get()` 的区别：`join` 抛非受检 `CompletionException`，`get` 抛受检 `InterruptedException` / `ExecutionException`
- 没有兜底：任一环节异常会导致整条链静默结束，必须挂 `exceptionally` / `handle`

## 动手练习

用 `CompletableFuture` 并行调用三个模拟接口，聚合结果后统一返回，并给整体加 2 秒超时与降级兜底。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《极致经典（卷 1/2/3）：Java 高并发核心编程》《Java多线程开发最佳实践手册》《深入理解高并发编程（第 2 版）》《实战高并发设计模式》对本节覆盖非常细致。

**thenCompose 的定位**

《极致经典（卷 2）》第 10.2.4 节专门讲「thenCompose() 方法」，这正是 CompletableFuture 家族最容易搞混的一组方法：

| 方法 | 上一阶段返回 | 何时用 |
| --- | --- | --- |
| `thenApply` | 普通值 T | 简单转换，T → U |
| `thenAccept` | 普通值 T | 只消费，不产出 |
| `thenRun` | 普通值 T | 不关心结果 |
| `thenCompose` | `CompletableFuture<U>` | **扁平化**，避免 `CF<CF<U>>` 嵌套 |

《极致经典（卷 3）》与《卷 1》都提到「异步回调模式」是 CompletableFuture 的核心价值——它把传统的「阻塞等待结果」变成「结果到达后触发回调」，让线程不被占着。

**默认线程池的风险**

《Java多线程开发最佳实践手册》在"CompletableFuture 异步编程"一节明确指出默认行为的问题：`supplyAsync` / `runAsync` 不传 Executor 时使用 `ForkJoinPool.commonPool()`。这个池是**全 JVM 共享**的：

- 它的并行度默认是 `CPU 核数 - 1`
- 所有未指定 Executor 的 CompletableFuture、以及 `parallelStream()` 都会用它
- 一旦某个任务阻塞（IO 等待），整个公共池可能被打满，**影响毫不相关的业务**

正解是显式传业务线程池。

**任务编排模式**

《实战高并发设计模式》第 4.2 节讲「任务编排」，《深入理解高并发编程（第 2 版）》提到「使用 CompletableFuture 来优化」这类场景。典型编排模式：

```java
// 顺序执行（串行依赖）
CompletableFuture.supplyAsync(this::stepA)
        .thenCompose(r -> CompletableFuture.supplyAsync(() -> stepB(r)))
        .thenAccept(this::stepC);

// 并行执行后聚合
CompletableFuture<String> userF = fetchUser();
CompletableFuture<List<Order>> orderF = fetchOrders();
userF.thenCombine(orderF, (u, os) -> merge(u, os))
     .thenAccept(this::save);
```

`thenCombine` 是两个**已有** CompletableFuture 的组合，`thenCompose` 是「上一个产出的 CF 再接下一个」。

**异常处理的三个方法**

《Java多线程开发最佳实践手册》对异常处理给了明确分工：

| 方法 | 何时执行 | 是否改变结果 |
| --- | --- | --- |
| `exceptionally` | 仅异常时 | 用返回值替换异常 |
| `handle` | 无论成败 | 用返回值替换结果或异常 |
| `whenComplete` | 无论成败 | **不改变**结果，仅做观察/日志 |

实践建议：链尾统一挂一个 `handle` 兜底，中间的异常让它自然向下传播。

**异步转同步的场景**

《从零开始手写 RPC 框架》提到「异步转同步」这个经典问题——框架内部用异步模型，但对外暴露同步接口。典型实现是「一个 Future + 一个阻塞等待的队列」：

```java
// 思路：异步执行 + CountDownLatch 等待
CountDownLatch latch = new CountDownLatch(1);
CompletableFuture.runAsync(() -> {
    try {
        doWork();
    } finally {
        latch.countDown();
    }
});
latch.await();
```

**超时与降级**

《Java多线程开发实战手册》强调生产环境必须为每个异步链路设超时，否则下游卡住会一路传导把上游线程池打满：

```java
// 超时抛异常
future.orTimeout(2, TimeUnit.SECONDS)
// 超时给默认值（降级）
future.completeOnTimeout("default", 2, TimeUnit.SECONDS)
```

## 实战提示

**生产环境的三条铁律**：

1. **永远显式传 Executor**，不要用公共池
2. **链尾永远挂兜底**，避免异常被静默吞掉
3. **每个异步链路都要有超时**，防止故障扩散

```java
private static final ExecutorService BIZ_POOL = Executors.newFixedThreadPool(
        Runtime.getRuntime().availableProcessors() * 2,
        new ThreadPoolExecutor.CallerRunsPolicy(),
        new ThreadPoolExecutor.AbortPolicy());   // 满时直接失败，配合上游重试

public <T> CompletableFuture<T> call(Supplier<T> supplier, long timeoutMs) {
    return CompletableFuture.supplyAsync(supplier, BIZ_POOL)
            .orTimeout(timeoutMs, TimeUnit.MILLISECONDS)
            .handle((r, ex) -> {
                if (ex != null) {
                    log.warn("异步调用失败", ex);
                    throw new CompletionException(ex);
                }
                return r;
            });
}
```

**注意线程池隔离**：不同业务用不同池，避免慢任务拖垮快任务。ThreadPoolExecutor 按业务维度划分（如 `orderPool`、`queryPool`）是常见做法。

**`join` vs `get`**：

| | `join()` | `get()` |
| --- | --- | --- |
| 抛出的异常 | `CompletionException`（非受检） | `ExecutionException`（受检） |
| 可中断 | 否 | 是（抛 `InterruptedException`） |
| 用在哪 | Lambda 表达式里 | 需要响应中断的地方 |

在 `thenApply` 的 lambda 里用 `join()` 更方便，因为受检异常没法在函数式接口里传。
' WHERE slug = 'completablefuture';

-- project-parallel-aggregate
UPDATE lesson SET content = '## 本节要点

并行聚合的核心是把大任务拆成小份并行执行再汇总。Java 提供的 `parallelStream`、分治递归、`CompletableFuture` 组合都是常见手段。真正的难点不在并行，而在**如何切分**与**如何控制线程数**。

## 核心概念

- **分治思想**：把问题拆成同类子问题并行求解，再合并结果（类似 `ForkJoinPool` 的 work-stealing）。
- **parallelStream**：基于 `Spliterator` + `ForkJoinPool.commonPool()`，三段式：中间操作 → 终端操作 → 归并。
- **Spliterator**：把流拆成可并行处理的片段，是并行流的底层抽象。
- **有状态操作与无状态操作**：无状态操作（map/filter）可完全并行；有状态操作（sorted/distinct/limit）需要缓冲区与合并。
- **短路操作**：`limit`、`findFirst`、`anyMatch` 会提前终止，可能导致任务未全部执行。
- **归约（reduce）**：三参数版本 `reduce(identity, accumulator, combiner)` 中，combiner 是并行归并的关键。
- **线程池占用**：parallelStream 默认使用 `ForkJoinPool.commonPool()`，并行度 = CPU 核数 - 1。
- **背压与数据倾斜**：分片不均会导致长尾任务拖慢整体。

## 关键代码

```java
// parallelStream：三段式流水线
long sum = list.parallelStream()
        .filter(n -> n % 2 == 0)
        .map(n -> n * n)
        .reduce(0L, Long::sum);

// 分治：把数组区间一分为二并行求和
long parallelSum(long[] arr, int lo, int hi) {
    if (hi - lo <= 16) {                    // 阈值以下直接串行算
        long s = 0;
        for (int i = lo; i < hi; i++) s += arr[i];
        return s;
    }
    int mid = (lo + hi) >>> 1;
    // ForkJoinPool 里会开新任务；普通线程池里用 invokeAll 更稳
    return parallelSum(arr, lo, mid) + parallelSum(arr, mid, hi);
}

// CompletableFuture 并行聚合三个来源
CompletableFuture<List<User>> uf = supplyAsync(() -> fetchUsers());
CompletableFuture<List<Order>> of = supplyAsync(() -> fetchOrders());
CompletableFuture<List<Point>> pf = supplyAsync(() -> fetchPoints());
CompletableFuture.allOf(uf, of, pf).thenRun(() -> {
    // join 三个结果汇总
});
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 在 parallelStream 里做阻塞 IO——公共池被占满，全应用卡顿
- 在 parallelStream 里用 `System.out.println` 等共享非线程安全的输出
- 以为并行一定更快——任务太小时线程调度开销远超收益
- 在 parallelStream 中使用有状态操作却不提供 combiner，导致结果异常
- 忽略公共池被其它 parallelStream 共享，一个慢任务拖垮全部

## 动手练习

用 parallelStream 与手写分治分别计算一千万个随机数的平方和，对比耗时并尝试不同的阈值。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《深入理解高并发编程：核心原理与案例实战-思维导图》《深入理解高并发编程（第 2 版）》《Java多线程开发最佳实践手册》《二哥的并发编程进阶之路》对本节方法论覆盖最全。

**操作系统线程调度这一层基础**

《深入理解高并发编程：核心原理与案例实战》思维导图的基础篇第 1 章是「操作系统线程调度」，其中 1.3 节「操作系统线程」覆盖了三种模型：

- 用户级线程（UPLT）：由用户空间的库调度，内核感知不到，多个用户线程映射到一个内核线程
- 内核级线程（KPLT）：由内核直接调度，一个对应一个
- 混合级线程：现代系统（如 Linux NPTL）的实现方式

1.4 节「Java 线程与操作系统线程的关系」明确 Java 采用**一对一映射**。这解释了为什么并行流在 Java 里能真正用满多核——但也说明线程创建成本高，必须复用。

**并发编程的基本概念**

同一份思维导图第 2 章「并发编程概述」包含：

- 2.1 程序、进程、线程
- 2.1.6 **同步与异步** —— 这正是本节并行聚合的方法论基础

**并行流的三个阶段**

《Java多线程开发最佳实践手册》在"并行 Stream 性能调优"一节给出了并行流的完整执行模型：

1. **拆分（Spliterator）**：把数据源切分成多个 Stream
2. **执行（ForkJoinPool）**：多个线程并行处理各个分片
3. **合并（Combining）**：把各分片结果归并成最终结果

理解这三个阶段才能解释几个现象：

- 为什么 `parallelStream().forEach()` 的**输出顺序不保证**——并行执行且不合并
- 为什么 `sorted()` 在并行流中开销大——它需要**全量收集后排序**（有状态操作）
- 为什么 `limit()` 可能导致任务没跑完——短路操作

**有状态 vs 无状态操作**

手册把操作分为两类：

| 类型 | 操作 | 并行特征 |
| --- | --- | --- |
| 无状态 | `map`、`filter`、`flatMap` | 每个元素独立处理，可完全并行 |
| 有状态 | `sorted`、`distinct`、`limit`、`skip` | 需要跨分片共享缓冲区或协调 |
| 中断性（短路） | `limit`、`findFirst`、`anyMatch` | 提前终止，可能有任务未执行 |

**并行归约的三参数 reduce**

《深入理解高并发编程（第 2 版）》与手册都强调三参数版本：

```java
.reduce(0L, Long::sum, Long::sum)
//        ↑identity  ↑accumulator(单分片内) ↑combiner(分片间合并)
```

`combiner` 缺失或错误是并行流结果异常的常见原因——它是**分片之间的合并逻辑**。

**公共池的共享风险**

手册在"线程池配置优化"一节强调：`ForkJoinPool.commonPool()` 是全 JVM 共享的，所有 parallelStream 与默认 CompletableFuture 都在用。因此：

- **阻塞 IO 绝不能放进 parallelStream**——会占满公共池
- 需要隔离时给 parallelStream 指定自定义 ForkJoinPool：

```java
ForkJoinPool custom = new ForkJoinPool(4);
try {
    custom.submit(() -> list.parallelStream().map(...).collect(...)).get();
} finally {
    custom.shutdown();
}
```

**CompletableFuture 做聚合**

《极致经典（卷 2/3）》与《实战高并发设计模式》第 4.2 节「任务编排」给出了另一种并行聚合方式。相比 parallelStream 的优势是**可以指定不同线程池、可以对每个子任务单独设超时**：

```java
// 三个来源并行，各自独立超时与降级
CompletableFuture<List<User>> uf = supplyAsync(this::fetchUsers, ioPool)
        .completeOnTimeout(List.of(), 2, TimeUnit.SECONDS);
```

**work-stealing 与任务粒度**

《二哥的并发编程进阶之路》提到 ForkJoinPool 的核心机制是 **work-stealing**：每个线程有自己的双端队列，队列空了就去别的线程"偷"任务。这带来一个重要实践结论：**任务粒度不能太小**，否则偷任务的开销超过收益。这也是手写分治要有「阈值以下直接串行」的原因。

## 实战提示

**是否用 parallelStream 的判断标准**：

| 场景 | 建议 |
| --- | --- |
| 纯计算、数据量大（>10万）、无共享状态 | 用 parallelStream |
| 涉及 IO / 远程调用 | 用 CompletableFuture + 独立线程池 |
| 数据量小（<1万） | 串行更快 |
| 有共享可变状态 | 不用，先改设计 |

**性能测试的正确做法**：

```java
// 1. 预热 JVM（让 JIT 编译完成，否则测的是解释执行）
for (int i = 0; i < 5; i++) { list.parallelStream().map(f).collect(toList()); }

// 2. 用 JMH 测（官方推荐，能排除 GC、JIT、伪共享干扰）
//    @Benchmark
//    @Fork(1) @Warmup(iterations = 5) @Measurement(iterations = 10)
//    public void testParallel() { ... }
```

JMH 是唯一可信的 Java 基准测试工具——手写 `System.nanoTime()` 循环会被 JIT 优化、GC 抖动、CPU 频率调节彻底干扰。

**真正的优化顺序**：先减小数据量 → 再考虑并行 → 最后才调线程数。绝大多数「并行不够快」的问题，其实是算法或数据量的问题。
' WHERE slug = 'project-parallel-aggregate';

-- spring-boot-init
UPDATE lesson SET content = '## 本节要点

Spring Boot 的核心是**自动装配**：通过 `@SpringBootApplication` 触发扫描，读取 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`（或旧版 `spring.factories`）里的配置类，按条件装配 Bean。理解这条链路，就理解了 Spring Boot 90% 的行为。

## 核心概念

- **@SpringBootApplication**：组合注解 = `@SpringBootConfiguration`（@Configuration）+ `@EnableAutoConfiguration` + `@ComponentScan`。
- **自动装配的三个步骤**：① 读取候选配置类 → ② 按 `@Conditional` 系列注解过滤 → ③ 注册为 Bean 定义。
- **条件注解**：`@ConditionalOnClass`（类路径有才装配）、`@ConditionalOnMissingBean`（用户没定义才装配）、`@ConditionalOnProperty`、`@ConditionalOnBean`。
- **@ConditionalOnMissingBean 的顺序敏感**：用户自定义的 Bean 必须先注册，所以自定义配置要放在自动配置之前。
- **starter 的作用**：一组依赖 + 一份自动配置类。
- **IoC 容器**：BeanFactory → ApplicationContext（Bean 生命周期、事件、国际化等）。
- **Bean 生命周期**：实例化 → 属性填充 → Aware 回调 → BeanPostProcessor 前置 → @PostConstruct → 初始化 → 后置 → @PreDestroy → 销毁。
- **BeanPostProcessor**：最关键的扩展点，AOP、@Autowired 的注入都靠它。
- **Bean 的作用域**：singleton（默认）、prototype、request、session。
- **循环依赖**：Spring 用三级缓存解决单例的字段注入循环依赖（构造器注入无法解决）。
- **配置方式**：application.yml > @ConfigurationProperties > @Value。
- **Actuator**：健康检查、指标、环境信息。

## 关键代码

```java
@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}

// 自定义配置：属性绑定
@ConfigurationProperties(prefix = "app.learning")
public record LearningProperties(int maxTasks, Duration timeout, boolean enabled) {
    // 构造器绑定（推荐）：record + @ConfigurationProperties
}

// 使用
@Service
public class TaskService {
    private final LearningProperties props;
    public TaskService(LearningProperties props) { this.props = props; }
}

// 条件装配示例
@Configuration
@ConditionalOnClass(RedisTemplate.class)
@ConditionalOnMissingBean(name = "customRedis")
public class RedisAutoConfig {
    @Bean
    public RedisTemplate<String, Object> redisTemplate() { ... }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 `@SpringBootApplication` 只能放在启动类——它会扫描所在包及子包
- 以为 `@ComponentScan` 会扫到所有依赖 jar——默认只扫启动类所在包
- 把 Bean 定义写在自动配置类里却不加 `@ConditionalOnMissingBean`，导致用户无法覆盖
- 用 `@Value` 注入复杂配置——类型受限且不支持嵌套结构，应该用 `@ConfigurationProperties`
- 构造器注入与字段注入混用

## 动手练习

写一个自定义 starter：包含 `XxxProperties`（`@ConfigurationProperties`）与 `XxxAutoConfiguration`（`@ConditionalOnMissingBean`），并在另一个项目中通过依赖引入。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《SpringIOC核心技术-冰河》《Spring源码深度解析（第 2 版）》《Spring 源码解析手册（星球专享）》《面渣逆袭 Spring 篇》《面试题-17-Spring Boot面试题》对本节原理有系统覆盖。

**自动装配的完整机制**

《SpringIOC核心技术-冰河》对 Spring 的 IOC 实现原理拆解得很细，与 Boot 的自动装配一脉相承：

```
启动 → SpringApplication.run()
  → 创建 ApplicationContext
  → 加载配置类（@SpringBootApplication 触发 @ComponentScan）
  → 读取 AutoConfiguration.imports 中的候选配置类
  → @Conditional 过滤（OnClass / OnMissingBean / OnProperty ...）
  → 注册 BeanDefinition
  → refresh() → 实例化单例 → 属性注入 → AOP 代理
```

《Spring源码深度解析（第 2 版）》与《Spring 源码解析手册》补充了 Spring Boot 2.7 之后的关键变化：**自动配置类注册文件的路径从 `META-INF/spring.factories` 改到了 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`**。原因是对 `spring.factories` 的自动配置支持被废弃，且一个文件只能声明一个自动配置类，新格式支持一行声明多个。

**条件注解体系**

《面试题-17-Spring Boot面试题》与《面渣逆袭 Spring 篇》列出了常用条件注解：

| 注解 | 生效条件 |
| --- | --- |
| `@ConditionalOnClass` | 类路径中存在指定类 |
| `@ConditionalOnMissingClass` | 类路径中**不**存在指定类 |
| `@ConditionalOnBean` | 容器中已有指定类型的 Bean |
| `@ConditionalOnMissingBean` | 容器中**没有**指定类型的 Bean |
| `@ConditionalOnProperty` | 配置项匹配指定值 |
| `@ConditionalOnWebApplication` | 是 Web 应用 |
| `@ConditionalOnExpression` | SpEL 表达式为真 |

**@ConditionalOnMissingBean 的使用规范**

《SpringIOC核心技术-冰河》与《面试题-17》强调这是 starter 开发的核心：

```java
@Bean
@ConditionalOnMissingBean      // 用户自己定义了就用用户的
public XxxService xxxService() { return new XxxService(); }
```

**顺序问题**：Spring Boot 2.0 之前要求自定义配置类放在 `@SpringBootApplication` 之后（因为自动配置在后处理）。2.1 之后改用 `AutoConfigureBefore` / `AutoConfigureAfter` 显式控制：

```java
@Configuration
@AutoConfigureBefore(MyAutoConfig.class)
public class MyConfig { ... }
```

**Bean 的生命周期与 BeanPostProcessor**

《SpringIOC核心技术-冰河》给出了完整生命周期：

```
实例化（构造器）
  → 属性填充（@Autowired、@Value）
  → Aware 接口回调（BeanNameAware / BeanFactoryAware / ApplicationContextAware）
  → BeanPostProcessor#postProcessBeforeInitialization（@PostConstruct 在此之后）
  → InitializingBean#afterPropertiesSet
  → BeanPostProcessor#postProcessAfterInitialization（AOP 代理在此生成）
  → 使用
  → @PreDestroy → DisposableBean#destroy → 自定义 destroy 方法
```

书中强调 **BeanPostProcessor 是 Spring 扩展的命脉**——AOP 代理、`@Autowired` 的注入、`@Async` 的异步化，全都在这里织入。

**循环依赖的三级缓存**

《Spring源码深度解析（第 2 版）》与《深入浅出Java+23种设计模式》都解释了三级缓存：

```
一级：singletonObjects      —— 完全初始化好的单例
二级：earlySingletonObjects —— 提前暴露的单例（可能还在填充属性）
三级：singletonFactories    —— 工厂函数（用于生成早期引用）
```

三级缓存是为了处理「A 的构造需要 B，B 的构造需要 A」这种**构造器注入**的循环依赖——三级缓存能拿到**原始引用**（可能是代理对象前的裸对象）。

**但字段注入的循环依赖是有害的**，《面试题-17》明确指出应当避免：

```java
// 不推荐：字段注入循环依赖
@Service class A { @Autowired B b; }
@Service class B { @Autowired A a; }

// 推荐：构造器注入（会在启动时快速失败）
@Service class A { A(B b) { this.b = b; } }
```

**@Value vs @ConfigurationProperties**

《面渣逆袭 Spring 篇》给出明确对比：

| | `@Value` | `@ConfigurationProperties` |
| --- | --- | --- |
| 粒度 | 单个属性 | 一批属性（一个类） |
| 类型 | 只支持简单类型 | 支持任意类型（嵌套对象、List、Map、Duration） |
| 校验 | 不支持 | 支持 JSR-303（`@Validated`） |
| 元数据 | 无 | 可生成 IDE 提示（配置元数据） |
| 写法 | `@Value("${a.b}")` | `@ConfigurationProperties(prefix="a.b")` |

**推荐做法**（书中给出）：

```java
@ConfigurationProperties(prefix = "app")
@Validated
public record AppProperties(
        @Min(1) @Max(100) int maxPoolSize,
        Duration timeout,
        Map<String, String> extras) {
}
```

**AOP 与动态代理**

《面渣逆袭 Spring 篇》指出 Spring AOP 的两种实现：JDK 动态代理（需接口）与 CGLIB（字节码增强）。Spring Boot 2.x 起默认 CGLIB。

《Spring 源码解析手册》补充了一个易踩的坑：**CGLIB 代理下 `@Transactional` 自调用失效**——因为代理对象与目标对象是不同实例，内部 `this.method()` 调用不经过代理。

```java
@Service
public class OrderService {
    public void outer() {
        this.inner();      // 自调用，不走代理 → @Transactional 不生效
    }
    @Transactional
    public void inner() { ... }
}
```

**常见 Starter 依赖坐标**

《面试题-17-Spring Boot面试题》提到官方 starter 的命名规范：

```
spring-boot-starter-web
spring-boot-starter-data-jpa
spring-boot-starter-test
mybatis-spring-boot-starter
```

自定义 starter 的命名一般是 `xxx-spring-boot-starter`。

**配置文件优先级**

《面渣逆袭 Spring 篇》给出 Spring Boot 配置的优先级顺序（高到低）：

1. 命令行参数 `--server.port=8081`
2. `SPRING_APPLICATION_JSON` 环境变量
3. ServletConfig / ServletContext 参数
4. JNDI（java:comp/env）
5. Java System Properties（`System.getProperties()`）
6. OS 环境变量
7. 打包外的 application.yml/properties
8. 打包内的 application.yml/properties
9. `@Profile` 指定的配置文件
10. `@PropertySource`

**Actuator 端点**

《面试题-17》列出了常用的 Actuator 端点：

```
/actuator/health        健康检查
/actuator/info          应用信息
/actuator/env           环境变量（敏感，需鉴权）
/actuator/metrics       指标
/actuator/threaddump    线程栈
/actuator/heapdump      堆快照
```

## 实战提示

**排查启动问题的顺序**：

```bash
# 1. 看自动装配报告（最有用）
java -jar app.jar --debug

# 2. 看某个自动配置为什么没生效
java -jar app.jar --debug=true   # 输出 ConditionEvaluationReport

# 3. 确认 Bean 是否注册
curl http://localhost:8080/actuator/conditions
```

**条件装配报告**是排查「为什么我的 Bean 没被创建」的最快手段——它会列出每个候选配置类**评估了哪些条件、哪个失败了**。

**推荐的配置组织方式**：

```yaml
app:
  learning:
    max-tasks: 10
    timeout: 30s          # Duration 类型：支持 30s / 30m
    features:
      - a
      - b
```

```java
@ConfigurationProperties(prefix = "app.learning")
public record LearningProperties(
        int maxTasks,
        Duration timeout,
        List<String> features) {
}
```

**Bean 注入统一用构造器**：

```java
// 更好：构造器注入 + final 字段
@Service
public class TaskService {
    private final TaskRepository repo;
    private final AppProperties props;

    public TaskService(TaskRepository repo, AppProperties props) {
        this.repo = repo;
        this.props = props;
    }
}
```

理由：① 依赖显式、② 字段可为 final、③ 单元测试可直接 new、④ 循环依赖能在启动时快速暴露。
' WHERE slug = 'spring-boot-init';

-- kingbase-persistence
UPDATE lesson SET content = '## 本节要点

在 KingbaseES（PostgreSQL 内核）上持久化，核心技术点是 **JDBC + 事务 + 索引 + 分页**。本项目用 Spring JDBC 的 `JdbcTemplate` 直接操作 SQL——相比 ORM 性能可控，也更容易看清数据库真实行为。

## 核心概念

- **JDBC 流程**：加载驱动 → 建立连接 → 创建 Statement → 执行 SQL → 处理 ResultSet → 关闭资源。
- **Connection**：代表一次会话。**必须关闭**，生产环境用连接池（HikariCP）。
- **Statement / PreparedStatement / CallableStatement**：预编译语句能防 SQL 注入并复用执行计划。
- **事务（ACID）**：原子性、一致性、隔离性、持久性。`setAutoCommit(false)` 开启事务。
- **隔离级别**：读未提交 / 读已提交 / 可重复读 / 可串行化。Kingbase 支持 PostgreSQL 的四种隔离级别（读已提交为默认）。
- **Savepoint**：事务内设置保存点，支持部分回滚。
- **索引**：B-tree 索引加速等值与范围查询；**索引会拖慢写入**（每次 INSERT/UPDATE 都要维护）。
- **联合索引的最左前缀规则**。
- **覆盖索引**：查询列全在索引里，无需回表。
- **分页**：OFFSET/LIMIT 深分页性能差（要扫描并丢弃前 N 行），用「游标分页」（keyset pagination）。
- **执行计划**：EXPLAIN / EXPLAIN ANALYZE 看索引是否命中、是否全表扫描。
- **慢查询日志**：定位性能问题的第一手段。
- **批量操作**：JDBC 的 addBatch/executeBatch 显著提升批量插入性能。
- **KingbaseES 与 PostgreSQL 兼容**：支持 `ON CONFLICT`、CTE、窗口函数、`jsonb` 类型。

## 关键代码

```java
// Spring JdbcTemplate：参数绑定，防 SQL 注入
@Repository
public class LessonRepository {
    private final JdbcTemplate jdbc;

    public LessonRepository(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public List<Lesson> findByModule(int moduleId) {
        // ? 是占位符，由驱动做参数绑定
        return jdbc.query("SELECT id, slug, title, duration_min FROM lesson WHERE module_id = ? ORDER BY sort_order",
                (rs, i) -> new Lesson(rs.getLong("id"), rs.getString("slug"),
                        rs.getString("title"), rs.getInt("duration_min")),
                moduleId);
    }

    // 批量插入
    public void batchInsert(List<Lesson> lessons) {
        jdbc.batchUpdate("INSERT INTO lesson (slug, title, duration_min) VALUES (?, ?, ?)",
                lessons, 500, (ps, l) -> {
                    ps.setString(1, l.slug());
                    ps.setString(2, l.title());
                    ps.setInt(3, l.durationMin());
                });
    }
}

// 事务：@Transactional 需要开启事务管理
@Service
public class OrderService {
    @Transactional
    public void create(Order order) {
        repo.insert(order);
        stockRepo.deduct(order);   // 一起成功或一起回滚
    }
}

// 手动控制事务（不依赖 Spring AOP 时）
try (Connection conn = dataSource.getConnection()) {
    conn.setAutoCommit(false);
    try (PreparedStatement ps = conn.prepareStatement(
            "INSERT INTO user_favorite (user_id, lesson_id) VALUES (?, ?) ON CONFLICT DO NOTHING")) {
        ps.setLong(1, userId);
        ps.setLong(2, lessonId);
        ps.executeUpdate();
        conn.commit();
    } catch (SQLException e) {
        conn.rollback();
        throw e;
    }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 字符串拼接 SQL——SQL 注入风险
- 忘记关闭 Connection / ResultSet / Statement——连接池被耗尽
- 认为加了事务就一定安全——隔离级别与并发冲突仍需处理
- 无脑给每个字段建索引——写入性能急剧下降
- 深分页用 OFFSET 100000——扫描成本随偏移量线性增长
- 在事务里做远程调用——长时间持有连接与锁

## 动手练习

用 `EXPLAIN ANALYZE` 对比有索引与无索引的查询计划，观察 Seq Scan 与 Index Scan 的差异。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《MySQL技术内幕：InnoDB存储引擎》《MySQL是怎样运行的：从根儿上理解MySQL》《面试题-09-MySQL数据库面试题》《面渣逆袭 MySQL》对本节原理有很好的迁移价值（B-tree 索引、MVCC、锁机制在 PostgreSQL/Kingbase 中概念一致）。

**B-tree 索引的原理**

《MySQL技术内幕：InnoDB存储引擎》详细讲解了 B+ 树索引的组织方式，KingbaseES（PostgreSQL 内核）用的是 B-tree，原理相通：

- **叶子节点存放数据项并用双向链表串起来**，支持范围扫描的高效性
- **非叶子节点只存键**，因此树更矮，磁盘 IO 次数少
- 高度为 3 的 B-tree 能存约 2000 万条记录（千万级数据表的索引只有 3 层）

《MySQL是怎样运行的》用大量图示讲解了 InnoDB 与 PostgreSQL 在索引实现上的差异：PostgreSQL 的索引项**直接指向堆表中的元组**（需要回表），且**堆表行不按顺序存储**（不像 MySQL 的聚簇索引），所以 PostgreSQL 下的范围查询更依赖索引本身有序。

**最左前缀原则**

《面渣逆袭 MySQL》与《MySQL技术内幕》都强调联合索引 `(a, b, c)` 的使用规则：

| SQL 条件 | 是否能用上索引 |
| --- | --- |
| `WHERE a = 1` | [OK] 只用 a |
| `WHERE a = 1 AND b = 2` | [OK] 用 a, b |
| `WHERE a = 1 AND b = 2 AND c = 3` | [OK] 全用 |
| `WHERE b = 2` | [X] 失效（跳过了最左列） |
| `WHERE a = 1 AND c = 3` | [OK] 用 a，c 需额外处理 |
| `ORDER BY a, b` | [OK] 利用索引有序性 |

**覆盖索引**

《面渣逆袭 MySQL》指出：当查询的所有列都在索引里时，数据库只需读索引不必回表，称为**覆盖索引**，能显著提升性能：

```sql
-- 若有索引 idx(user_id, lesson_id, study_count)
SELECT lesson_id, study_count FROM learning_progress WHERE user_id = 1;
-- 全部列在索引中 → Index Only Scan
```

本项目的 `learning_progress` 表就有 `(user_id, lesson_id)` 唯一约束（ON CONFLICT 的依据），这个索引同时服务了按用户查全部进度、按用户+课时查单条两种场景。

**MVCC 与隔离级别**

《MySQL是怎样运行的》系统讲解了多版本并发控制（MVCC），PostgreSQL/Kingbase 的实现思路类似：

- 每行数据有 `xmin`（插入事务 ID）与 `xmax`（删除事务 ID）
- 读操作不加锁，读取「对当前事务可见的版本」
- 写操作会创建新版本

《面试题-09-MySQL数据库面试题》列出了四种隔离级别与对应的并发问题：

| 隔离级别 | 脏读 | 不可重复读 | 幻读 |
| --- | --- | --- | --- |
| 读未提交 | 可能 | 可能 | 可能 |
| 读已提交 | 否 | 可能 | 可能 |
| 可重复读 | 否 | 否 | 可能（间隙锁缓解） |
| 可串行化 | 否 | 否 | 否 |

Kingbase 默认是**读已提交**，与 PostgreSQL 一致。

**KingbaseES 的兼容性特色**

本项目已经在用的语法（都是 PostgreSQL 风格）：

```sql
-- 1. UPSERT
INSERT INTO learning_progress (...) VALUES (...)
ON CONFLICT (user_id, lesson_id) DO UPDATE SET
    total_seconds = learning_progress.total_seconds + EXCLUDED.total_seconds,
    study_count  = learning_progress.study_count + CASE
        WHEN EXCLUDED.last_session_key IS NOT NULL
        AND learning_progress.last_session_key IS DISTINCT FROM EXCLUDED.last_session_key
        THEN 1 ELSE 0 END;

-- 2. CTE（公共表表达式）
WITH top_lesson AS (
    SELECT lesson_id, SUM(total_seconds) AS secs
    FROM learning_progress GROUP BY lesson_id
)
SELECT l.title, t.secs FROM top_lesson t JOIN lesson l ON l.id = t.lesson_id
ORDER BY t.secs DESC LIMIT 10;

-- 3. 窗口函数
SELECT lesson_id, total_seconds,
       ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY total_seconds DESC) AS rn
FROM learning_progress;

-- 4. jsonb
SELECT content::jsonb -> ''points'' FROM course WHERE id = 1;
```

《面渣逆袭 MySQL》讲到 JSON 处理时会对比 MySQL 的 json 类型与 PostgreSQL 的 `jsonb`——KingbaseES 支持 `jsonb`，且支持 GIN 索引。

**慢查询日志**

《MySQL技术内幕》与《面渣逆袭 MySQL》都把慢查询日志列为性能排查第一手段。KingbaseES 中对应配置：

```
log_min_duration_statement = 500     # 记录超过 500ms 的语句
log_statement = ''all''                # 记录所有语句（临时排查用）
```

**深分页问题**

《面渣逆袭 MySQL》详细分析了深分页为什么慢：`LIMIT 100000, 20` 需要扫描 100020 行并丢弃前 100000 行，偏移量越大越慢。解决方案是**游标分页（keyset pagination）**：

```sql
-- 慢：偏移 100000
SELECT * FROM lesson ORDER BY id LIMIT 20 OFFSET 100000;

-- 快：用上一页最后一个 id 作为游标
SELECT * FROM lesson WHERE id > :lastId ORDER BY id LIMIT 20;
```

本项目的课程列表若要支持深分页，应采用这种方案。

## 实战提示

**必须遵守的几条**：

1. **永远用参数绑定**，绝不拼接 SQL
2. **资源用 try-with-resources**，或用 `JdbcTemplate`（自动管理）
3. **事务方法里不做远程调用**——长时间持有连接和锁
4. **写操作前先看执行计划**：`EXPLAIN ANALYZE`

**索引设计的基本原则**：

```sql
-- 覆盖常见查询：按用户查进度
CREATE INDEX idx_progress_user ON learning_progress(user_id);
-- 高频筛选字段
CREATE INDEX idx_lesson_module ON lesson(module_id, sort_order);
```

**但不要过度索引**：每加一个索引，INSERT/UPDATE/DELETE 都要多维护一份 B-tree。经验值是**单表索引不超过 5 个**。

**连接池配置（本项目已在用）**：

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10      # 经验值：CPU核数 * 2 + 磁盘数
      minimum-idle: 2
      connection-timeout: 10000
      pool-name: kb-pool
```

**排查慢 SQL 的完整流程**：

```sql
-- 1. 找到慢查询
SELECT query, calls, mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 10;

-- 2. 看执行计划
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;

-- 3. 看表与索引使用情况
SELECT schemaname, relname, seq_scan, idx_scan
FROM pg_stat_user_tables
ORDER BY seq_scan DESC;
```

`pg_stat_statements` 需要在 `postgresql.conf` 里开启 `shared_preload_libraries = ''pg_stat_statements''`。KingbaseES 兼容这一扩展。
' WHERE slug = 'kingbase-persistence';

-- restful-api
UPDATE lesson SET content = '## 本节要点

RESTful 是一组**架构约束**，不是协议。核心约束是：资源用 URI 标识、用 HTTP 方法表达动作、用状态码表达结果、用 JSON 承载数据。好的 RESTful API 应该是**可预测**的——同一个 URI 在任何地方都表示同一个东西。

## 核心概念

- **资源（Resource）**：名词。用 URI 标识，不用动词。
- **HTTP 方法语义**：GET 查、POST 增、PUT 全量改、PATCH 部分改、DELETE 删。**GET 必须安全**（不改状态），**PUT/DELETE 必须幂等**。
- **状态码分类**：
  - 2xx 成功：200 OK、201 Created（带 Location 头）、202 Accepted（异步）、204 No Content
  - 3xx 重定向：301 永久、302 临时、304 未修改（配合 ETag）
  - 4xx 客户端错误：400 参数错误、401 未认证、403 无权限、404 不存在、409 冲突、422 语义错误、429 限流
  - 5xx 服务端错误：500 内部错误、502 网关错误、503 服务不可用、504 网关超时
- **HATEOAS**：通过响应中的链接告诉客户端下一步能做什么（`_links`）。
- **版本化**：URL 路径（`/api/v1/...`）vs 请求头（`Accept: application/vnd.x.v1+json`）。路径版本更直观，实践更常用。
- **幂等性**：同一请求执行多次与执行一次效果相同。PUT/DELETE 必须幂等，POST 默认不幂等（需幂等键）。
- **分页**：offset 分页（简单但深分页慢）与 cursor 分页（keyset，深分页友好）。
- **统一响应格式**：固定结构便于客户端处理。
- **内容协商**：`Accept` 请求期望的格式，`Content-Type` 响应的格式。
- **条件请求**：ETag + If-None-Match、Last-Modified + If-Modified-Since，实现 304。
- **软删除**：DELETE 只标记 `deleted_at`，保留数据。

## 关键代码

```java
@RestController
@RequestMapping("/api/lessons")
public class LessonController {

    // GET：安全、幂等、只读
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<LessonVo>> get(@PathVariable Long id) {
        return lessonService.findById(id)
                .map(l -> ResponseEntity.ok(ApiResponse.ok(LessonVo.from(l))))
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(ApiResponse.fail("LESSON_NOT_FOUND", "课时不存在")));
    }

    // POST：创建，返回 201 + Location
    @PostMapping
    public ResponseEntity<ApiResponse<LessonVo>> create(@Valid @RequestBody CreateLessonRequest req) {
        LessonVo vo = lessonService.create(req);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}").buildAndExpand(vo.id()).toUri();
        return ResponseEntity.created(location).body(ApiResponse.ok(vo));
    }

    // PUT：全量替换，幂等
    @PutMapping("/{id}")
    public ApiResponse<Void> update(@PathVariable Long id, @Valid @RequestBody UpdateLessonRequest req) {
        lessonService.update(id, req);
        return ApiResponse.ok();
    }

    // PATCH：部分更新
    @PatchMapping("/{id}")
    public ApiResponse<Void> patch(@PathVariable Long id, @RequestBody Map<String, Object> patch) {
        lessonService.patch(id, patch);
        return ApiResponse.ok();
    }

    // DELETE：幂等（删不存在的也返回 204）
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        lessonService.softDelete(id);
        return ResponseEntity.noContent().build();
    }

    // 分页 + 过滤
    @GetMapping
    public ApiResponse<PageResult<LessonVo>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String keyword) {
        return ApiResponse.ok(lessonService.page(page, size, keyword));
    }
}

// 统一响应格式
public record ApiResponse<T>(int code, String message, T data, long timestamp) {
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(0, "success", data, System.currentTimeMillis());
    }
    public static <T> ApiResponse<T> fail(String code, String message) {
        return new ApiResponse<>(-1, message, null, System.currentTimeMillis());
    }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- URI 里用动词——`/getUserList`、`/createOrder` 应改为 `/users`、`/orders`
- 所有响应都返回 200，用 body 里的 code 表达错误——破坏了 HTTP 语义
- GET 请求里有副作用（删除、修改）——违反安全性约束
- 忘记分页——全量返回在数据增长后必然拖垮服务
- PUT 不幂等——重复调用产生重复数据
- 错误地把业务错误码与 HTTP 状态码混用

## 动手练习

为课程设计一套 RESTful 接口：列出课时、查看详情、标记完成、收藏，并用 curl 验证状态码与幂等性。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Offer来了：Java面试核心知识点精讲. 原理篇》《面渣逆袭-分布式篇》《深入浅出Java+23种设计模式》《面试题-15-消息中间件MQ面试题》对 REST 规范、幂等性、分布式场景下的 API 设计有系统论述。

**《Offer来了》原理篇的 RESTful 章节**

《Offer来了：Java面试核心知识点精讲. 原理篇》开篇即讲 JVM 原理、Java 基础、多线程、数据结构、分布式缓存、设计模式等，其中 RESTful 设计给出的原则与本节一致：

- **URL 用名词**：资源用复数形式（`/users` 而不是 `/user`、`/getUser`）
- **HTTP 方法表达动作**：不用自定义动词（`/users/list` 改为 `GET /users?role=admin`）
- **状态码语义化**：不要所有情况都返回 200

**幂等性的工程价值**

《面渣逆袭-分布式篇》把幂等性放在分布式章节里讨论，因为它是分布式可靠性的基石：

```sql
-- 幂等键实现（配合唯一约束）
INSERT INTO payment (order_id, idempotent_key, amount)
VALUES (?, ?, ?)
ON CONFLICT (idempotent_key) DO NOTHING;
```

书中指出幂等键（Idempotency Key）的标准做法：

1. 客户端为每个业务操作生成唯一键（如 UUID）
2. 服务端用该键做唯一约束插入
3. 重复请求命中约束 → 返回首次的结果，不重复执行

这正好是本项目 `learning_progress` 表用 `ON CONFLICT (user_id, lesson_id) DO UPDATE` 的思路——`sessionKey` 扮演了幂等键的角色。

**HTTP 方法的安全性与幂等性对照**

《深入浅出Java+23种设计模式》与《Offer来了》都给出这张表：

| 方法 | 安全 | 幂等 | 典型用途 |
| --- | --- | --- | --- |
| GET | [OK] | [OK] | 查询 |
| POST | [X] | [X] | 创建 |
| PUT | [X] | [OK] | 全量替换 |
| PATCH | [X] | [X]（视实现） | 部分更新 |
| DELETE | [X] | [OK] | 删除 |

**幂等不等于安全**：DELETE 不安全（会改状态）但幂等（删多次与删一次效果相同）。

**CAP 原则与 API 设计**

《面渣逆袭-分布式篇》开篇讲 CAP 定理（一致性 C、可用性 A、分区容错性 P，最多满足两个），这与 API 设计的关系是：**在分区必然发生的分布式系统里，接口必须能处理「调用方重试」**。因此写接口时若不做幂等设计，等于把重试的风险推给了调用方。

书中还讲「异步确保型事务」（outbox / 事务消息）：先在本地事务里写消息表，再异步投递，保证「本地事务成功但消息发送失败」这类不一致不会发生。

**REST 与状态码的实战约定**

《面渣逆袭-分布式篇》在讨论消息队列的「幂等性」时也提到 HTTP 层的一致做法：

| 场景 | 状态码 | 说明 |
| --- | --- | --- |
| 创建成功 | 201 | 带 Location 头 |
| 异步处理中 | 202 | 立即返回，后续查状态 |
| 删除成功 | 204 | 无 body |
| 参数格式错误 | 400 | |
| 未认证 | 401 | 带 WWW-Authenticate |
| 已认证但无权限 | 403 | |
| 资源不存在 | 404 | |
| 状态冲突 | 409 | 如重复提交 |
| 触发限流 | 429 | 带 Retry-After |
| 服务端异常 | 500 | |
| 依赖服务不可用 | 503 | 带 Retry-After |

**401 vs 403 的区别**是高频考点：401 是「你是谁？我不知道」，403 是「我知道你是谁，但你不能做这个」。

**HATEOAS 与超媒体**

《深入浅出Java+23种设计模式》与《Offer来了》都提到 REST 的第六条约束（统一接口）背后的理念——**把状态机暴露给客户端**：

```json
{
  "data": { "id": 1001, "status": "CREATED" },
  "_links": {
    "self":    { "href": "/api/orders/1001" },
    "pay":     { "href": "/api/orders/1001/payment", "method": "POST" },
    "cancel":  { "href": "/api/orders/1001/cancel",  "method": "POST" }
  }
}
```

客户端只需看 `_links` 就知道下一步能做什么，不必硬编码状态机逻辑。

**版本化的取舍**

《面渣逆袭-分布式篇》与《Offer来了》都指出：

- **URL 版本**（`/api/v1/users`）：直观、易调试、便于灰度，实践中最常用
- **请求头版本**（`Accept: application/vnd.api.v1+json`）：更"纯粹"（同一资源多个表示），但调试与网关配置复杂
- 兼容性原则：**新增字段永远兼容，删除/改名字段需要大版本**

**Spring Boot 3 的 API 错误处理**

本项目已在用 `@RestControllerAdvice` 做统一异常处理（见异常处理课时）。《面渣逆袭 Spring 篇》指出这与 REST 规范配合时的要点：

- 业务异常 → 4xx + 业务错误码
- 系统异常 → 500 + 通用提示（**不要把堆栈返回给客户端**）
- 参数校验失败 → 400 + 字段级错误信息

## 实战提示

**统一响应结构的建议**：

```java
public record ApiResponse<T>(int code, String message, T data, long timestamp) {
    public static <T> ApiResponse<T> ok(T data) { ... }
    public static <T> ApiResponse<T> fail(String code, String message) { ... }
}
```

注意：**HTTP 状态码与 body 里的 code 要各司其职**——HTTP 状态码表达协议层结果（给中间件、网关看），body 的 code 表达业务语义（给前端判断）。

**幂等键的落地写法**：

```java
@PostMapping("/orders")
public ResponseEntity<ApiResponse<OrderVo>> create(
        @RequestHeader(value = "Idempotency-Key", required = false) String key,
        @Valid @RequestBody CreateOrderRequest req) {
    OrderVo vo = orderService.createWithIdempotency(key, req);
    return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(vo));
}
```

**分页响应的标准结构**：

```json
{
  "code": 0,
  "data": {
    "items": [],
    "page": 0, "size": 20, "total": 42,
    "hasNext": true
  }
}
```

**设计 API 时的自查清单**：

- [ ] URI 是名词复数，没有动词
- [ ] GET 绝不修改数据
- [ ] PUT / DELETE 幂等（重复调用效果相同）
- [ ] 状态码语义正确，不是清一色 200
- [ ] 有分页（且支持上限保护）
- [ ] 错误响应不泄露内部细节
- [ ] 写操作考虑幂等键
- [ ] 时间格式统一 ISO-8601，时区明确
' WHERE slug = 'restful-api';

COMMIT;
