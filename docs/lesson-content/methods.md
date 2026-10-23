## 本节要点

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
    p.setName("changed");   // ✔ 有效 —— 改的是同一个对象
    p = new Person("new");  // ✘ 无效 —— 只改了形参这个引用
}

static void modifyInt(int n) {
    n = 100;                // ✘ 无效 —— 形参是值的拷贝
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
