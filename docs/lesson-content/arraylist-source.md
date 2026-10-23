## 本节要点

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
