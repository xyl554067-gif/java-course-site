## 本节要点

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
