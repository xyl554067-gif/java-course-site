## 本节要点

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
