## 本节要点

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
