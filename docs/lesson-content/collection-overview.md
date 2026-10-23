## 本节要点

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
| List | ✔ | ✔ | ✔ | ✘ |
| Set | 部分（LinkedHashSet/TreeSet） | ✘ | ✘ | ✘ |
| Map | 部分（LinkedHashMap/TreeMap） | key 唯一 | ✘ | ✔ |

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
