## 本节要点

并行聚合的核心是把大任务拆成小份并行执行再汇总。Java 提供的 `parallelStream`、分治递归、`CompletableFuture` 组合都是常见手段。真正的难点不在并行，而在**如何切分**与**如何控制线程数**。

## 核心概念

- **分治思想**：把问题拆成同类子问题并行求解，再合并结果（类似 `ForkJoinPool` 的 work-stealing）。
- **parallelStream**：基于 `Spliterator` + `ForkJoinPool.commonPool()`，三段式：中间操作 → 终端操作 → 归并。
- **Spliterator**：把流拆成可并行处理的片段，是并行流的底层抽象。
- **有状态操作与无状态操作**：无状态操作（map/filter）可完全并行；有状态操作（sorted/distinct/limit）需要缓冲区与合并。
- **短路操作**：`limit`、`findFirst`、`anyMatch` 会提前终止，可能导致任务未全部执行。
- **归约（reduce）**：三参数版本 `reduce(identity, accumulator, combiner)` 中，combiner 是并行归并的关键。
- **线程池占用**：parallelStream 默认使用 `ForkJoinPool.commonPool()`，并行度 = CPU 核数 − 1。
- **背压与数据倾斜**：分片不均会导致长尾任务拖慢整体。

## 关键代码

```java
// parallelStream：三段式流水线
long sum = list.parallelStream()
        .filter(n -> n % 2 == 0)
        .map(n -> n * n)
        .reduce(0L, Long::sum);

// 分治：把数组区间一分为二并行求和
long parallelSum(long[] arr, int lo, int hi) {
    if (hi - lo <= 16) {                    // 阈值以下直接串行算
        long s = 0;
        for (int i = lo; i < hi; i++) s += arr[i];
        return s;
    }
    int mid = (lo + hi) >>> 1;
    // ForkJoinPool 里会开新任务；普通线程池里用 invokeAll 更稳
    return parallelSum(arr, lo, mid) + parallelSum(arr, mid, hi);
}

// CompletableFuture 并行聚合三个来源
CompletableFuture<List<User>> uf = supplyAsync(() -> fetchUsers());
CompletableFuture<List<Order>> of = supplyAsync(() -> fetchOrders());
CompletableFuture<List<Point>> pf = supplyAsync(() -> fetchPoints());
CompletableFuture.allOf(uf, of, pf).thenRun(() -> {
    // join 三个结果汇总
});
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 在 parallelStream 里做阻塞 IO——公共池被占满，全应用卡顿
- 在 parallelStream 里用 `System.out.println` 等共享非线程安全的输出
- 以为并行一定更快——任务太小时线程调度开销远超收益
- 在 parallelStream 中使用有状态操作却不提供 combiner，导致结果异常
- 忽略公共池被其它 parallelStream 共享，一个慢任务拖垮全部

## 动手练习

用 parallelStream 与手写分治分别计算一千万个随机数的平方和，对比耗时并尝试不同的阈值。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《深入理解高并发编程：核心原理与案例实战-思维导图》《深入理解高并发编程（第 2 版）》《Java多线程开发最佳实践手册》《二哥的并发编程进阶之路》对本节方法论覆盖最全。

**操作系统线程调度这一层基础**

《深入理解高并发编程：核心原理与案例实战》思维导图的基础篇第 1 章是「操作系统线程调度」，其中 1.3 节「操作系统线程」覆盖了三种模型：

- 用户级线程（UPLT）：由用户空间的库调度，内核感知不到，多个用户线程映射到一个内核线程
- 内核级线程（KPLT）：由内核直接调度，一个对应一个
- 混合级线程：现代系统（如 Linux NPTL）的实现方式

1.4 节「Java 线程与操作系统线程的关系」明确 Java 采用**一对一映射**。这解释了为什么并行流在 Java 里能真正用满多核——但也说明线程创建成本高，必须复用。

**并发编程的基本概念**

同一份思维导图第 2 章「并发编程概述」包含：

- 2.1 程序、进程、线程
- 2.1.6 **同步与异步** —— 这正是本节并行聚合的方法论基础

**并行流的三个阶段**

《Java多线程开发最佳实践手册》在"并行 Stream 性能调优"一节给出了并行流的完整执行模型：

1. **拆分（Spliterator）**：把数据源切分成多个 Stream
2. **执行（ForkJoinPool）**：多个线程并行处理各个分片
3. **合并（Combining）**：把各分片结果归并成最终结果

理解这三个阶段才能解释几个现象：

- 为什么 `parallelStream().forEach()` 的**输出顺序不保证**——并行执行且不合并
- 为什么 `sorted()` 在并行流中开销大——它需要**全量收集后排序**（有状态操作）
- 为什么 `limit()` 可能导致任务没跑完——短路操作

**有状态 vs 无状态操作**

手册把操作分为两类：

| 类型 | 操作 | 并行特征 |
| --- | --- | --- |
| 无状态 | `map`、`filter`、`flatMap` | 每个元素独立处理，可完全并行 |
| 有状态 | `sorted`、`distinct`、`limit`、`skip` | 需要跨分片共享缓冲区或协调 |
| 中断性（短路） | `limit`、`findFirst`、`anyMatch` | 提前终止，可能有任务未执行 |

**并行归约的三参数 reduce**

《深入理解高并发编程（第 2 版）》与手册都强调三参数版本：

```java
.reduce(0L, Long::sum, Long::sum)
//        ↑identity  ↑accumulator(单分片内) ↑combiner(分片间合并)
```

`combiner` 缺失或错误是并行流结果异常的常见原因——它是**分片之间的合并逻辑**。

**公共池的共享风险**

手册在"线程池配置优化"一节强调：`ForkJoinPool.commonPool()` 是全 JVM 共享的，所有 parallelStream 与默认 CompletableFuture 都在用。因此：

- **阻塞 IO 绝不能放进 parallelStream**——会占满公共池
- 需要隔离时给 parallelStream 指定自定义 ForkJoinPool：

```java
ForkJoinPool custom = new ForkJoinPool(4);
try {
    custom.submit(() -> list.parallelStream().map(...).collect(...)).get();
} finally {
    custom.shutdown();
}
```

**CompletableFuture 做聚合**

《极致经典（卷 2/3）》与《实战高并发设计模式》第 4.2 节「任务编排」给出了另一种并行聚合方式。相比 parallelStream 的优势是**可以指定不同线程池、可以对每个子任务单独设超时**：

```java
// 三个来源并行，各自独立超时与降级
CompletableFuture<List<User>> uf = supplyAsync(this::fetchUsers, ioPool)
        .completeOnTimeout(List.of(), 2, TimeUnit.SECONDS);
```

**work-stealing 与任务粒度**

《二哥的并发编程进阶之路》提到 ForkJoinPool 的核心机制是 **work-stealing**：每个线程有自己的双端队列，队列空了就去别的线程"偷"任务。这带来一个重要实践结论：**任务粒度不能太小**，否则偷任务的开销超过收益。这也是手写分治要有「阈值以下直接串行」的原因。

## 实战提示

**是否用 parallelStream 的判断标准**：

| 场景 | 建议 |
| --- | --- |
| 纯计算、数据量大（>10万）、无共享状态 | 用 parallelStream |
| 涉及 IO / 远程调用 | 用 CompletableFuture + 独立线程池 |
| 数据量小（<1万） | 串行更快 |
| 有共享可变状态 | 不用，先改设计 |

**性能测试的正确做法**：

```java
// 1. 预热 JVM（让 JIT 编译完成，否则测的是解释执行）
for (int i = 0; i < 5; i++) { list.parallelStream().map(f).collect(toList()); }

// 2. 用 JMH 测（官方推荐，能排除 GC、JIT、伪共享干扰）
//    @Benchmark
//    @Fork(1) @Warmup(iterations = 5) @Measurement(iterations = 10)
//    public void testParallel() { ... }
```

JMH 是唯一可信的 Java 基准测试工具——手写 `System.nanoTime()` 循环会被 JIT 优化、GC 抖动、CPU 频率调节彻底干扰。

**真正的优化顺序**：先减小数据量 → 再考虑并行 → 最后才调线程数。绝大多数「并行不够快」的问题，其实是算法或数据量的问题。
