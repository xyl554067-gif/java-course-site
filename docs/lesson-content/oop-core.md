## 本节要点

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
