## 本节要点

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
