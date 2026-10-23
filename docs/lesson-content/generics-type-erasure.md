## 本节要点

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
