## 本节要点

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
