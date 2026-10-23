## 本节要点

线程池通过复用线程降低创建销毁开销，并用**队列 + 拒绝策略**应对任务超出处理能力的情况。`ThreadPoolExecutor` 的四个关键参数（核心数、最大数、空闲存活时间、工作队列）决定了它的全部行为。

## 核心概念

- **核心线程数（corePoolSize）**：池中常驻线程数，任务优先由核心线程处理。
- **最大线程数（maximumPoolSize）**：队列满后可创建的上限。
- **空闲存活时间（keepAliveTime）**：非核心线程空闲多久后回收。
- **工作队列（workQueue）**：核心线程忙时，任务在此排队。
- **拒绝策略（rejectionHandler）**：线程数达上限且队列满时怎么办。
- **执行流程**：核心线程 → 队列 → 扩到最大线程 → 拒绝策略。
- **四种拒绝策略**：AbortPolicy（抛异常）、CallerRunsPolicy（调用方线程执行）、DiscardPolicy（丢弃）、DiscardOldestPolicy（丢最老的）。
- **为什么不建议用 Executors**：newFixedThreadPool / newSingleThreadExecutor 用无界队列（OOM 风险）；newCachedThreadPool 用 SynchronousQueue 且最大线程数无限（同样 OOM 风险）。
- **线程池状态**：RUNNING → SHUTDOWN → STOP → TIDYING → TERMINATED。
- **任务类型**：Runnable 无返回值，Callable 有返回值可抛异常（需配合 FutureTask）。

## 关键代码

```java
// 推荐显式 new ThreadPoolExecutor，避免 Executors 的无界队列问题
ThreadPoolExecutor pool = new ThreadPoolExecutor(
        4,                      // 核心线程数
        8,                      // 最大线程数
        60L, TimeUnit.SECONDS,  // 空闲存活时间
        new ArrayBlockingQueue<>(200),   // 有界队列
        new ThreadPoolExecutor.CallerRunsPolicy()  // 背压：调用方自己跑
);

pool.execute(() -> System.out.println("task"));

// 有返回值的任务
Future<Integer> f = pool.submit(() -> 42);
System.out.println(f.get());

// 优雅关闭
pool.shutdown();                  // 不再接收新任务，跑完存量后终止
// pool.shutdownNow();           // 立即中断
pool.awaitTermination(30, TimeUnit.SECONDS);

// 线程池中的 ThreadLocal 必须清理
pool.execute(() -> {
    try {
        CTX.set(user);
        // 业务
    } finally {
        CTX.remove();            // 线程会被复用，不 remove 会串数据
    }
});
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 用 `Executors.newFixedThreadPool` 图省事，无界队列导致 OOM
- 认为线程池越大吞吐越高，忽略了上下文切换与内存开销
- 用 `shutdownNow()` 粗暴中断，任务里的资源没机会清理
- 忘了 `execute` 与 `submit` 的差别：`execute` 抛出的异常由线程的 UncaughtExceptionHandler 处理，`submit` 的异常被吞进 Future 里

## 动手练习

用自定义 ThreadPoolExecutor 模拟任务队列打满，观察 CallerRunsPolicy 下调用方线程被迫执行任务的效果。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《深入浅出 Java 多线程-RedSpider》《Java多线程开发最佳实践手册》《二哥的并发编程进阶之路》《深入理解高并发编程（第 2 版）》以及《面渣逆袭Java并发编程》对本节覆盖完整。

**线程池的复用机制**

《二哥的并发编程进阶之路》指出，线程池的核心是「池中的空闲线程异步提交任务」的复用模型。完整执行链路（与《深入浅出 Java 多线程》一致）：

1. 线程池为空 → 创建核心线程执行
2. 核心线程已满 → 任务进入工作队列
3. 队列满 → 创建非核心线程（直到 maximumPoolSize）
4. 线程数达上限且队列满 → 执行拒绝策略

《深入理解 JVM 核心技术》提到一个设计要点：「丢弃任务可重用固定线程数的线程池」——这正是 `CallerRunsPolicy` 的思路：宁可让提交方自己跑，也不丢任务，从而把压力反传给上游。

**线程池参数的经验值**

《Java多线程开发最佳实践手册》的"线程池配置优化"章节给出了系统的建议：

- **CPU 密集型**：N+1（N 为核数），因为线程大部分时间在计算，额外一个用于处理突发
- **IO 密集型**：N × (1 + WT/CT)，WT 为等待时间，CT 为计算时间
- 队列容量：不宜过大。队列越大，任务的实际延迟越长（排在第 N 个位置的任务要等前面全部完成）
- `keepAliveTime`：非核心线程的回收时间，一般 30s–60s

**RejectedExecutionHandler 的四种策略**

知识库中《深入浅出 Java 多线程》列出了完整的策略表：

| 策略 | 行为 | 适用场景 |
| --- | --- | --- |
| AbortPolicy | 抛 `RejectedExecutionException` | 需要感知拒绝并快速失败 |
| CallerRunsPolicy | 由提交任务的线程执行 | **背压首选**，天然限流 |
| DiscardPolicy | 静默丢弃 | 可丢失的任务（如埋点） |
| DiscardOldestPolicy | 丢弃队列头部最老的，重试入队 | 需要保新弃旧 |

**默认实现与推荐的差异**

《二哥的并发编程进阶之路》与《面渣逆袭Java并发编程》都提醒：`Executors` 工厂方法提供了便捷但有隐患的实现：

- `newFixedThreadPool(n)` / `newSingleThreadExecutor()` → `LinkedBlockingQueue` **无界队列**，任务堆积到 OOM
- `newCachedThreadPool()` → `SynchronousQueue` + `maximumPoolSize = Integer.MAX_VALUE`，线程数无限增长到 OOM
- `newScheduledThreadPool(n)` → 同样是无界的 `DelayedWorkQueue`

正解是显式 `new ThreadPoolExecutor(...)`，配上有界队列与 `CallerRunsPolicy`。

**线程池的状态机**

《深入浅出 Java 多线程》给出完整状态定义：

| 状态 | 说明 |
| --- | --- |
| RUNNING | 正常运行，接受新任务并处理队列任务 |
| SHUTDOWN | 不再接受新任务，继续处理队列中已有任务 |
| STOP | 不再接受新任务，中断正在执行的任务，清空队列 |
| TIDYING | 所有任务已终止，等待线程数归零 |
| TERMINATED | 线程池彻底关闭 |

`shutdown()` 与 `shutdownNow()` 的区别正对应 SHUTDOWN 与 STOP。

**JUC 的同步工具**

《Java多线程开发最佳实践手册》还覆盖了常用同步器，它们常常比 `synchronized` 更贴合场景：

- `CountDownLatch`：一个或多个线程等待其他线程完成（适合并行任务汇合）
- `CyclicBarrier`：一组线程互相等待（适合分阶段计算）
- `Semaphore`：通过许可数限制并发量（适合限流）
- `Phaser`：可动态注册参与者的分阶段屏障

## 实战提示

**给线程池加监控**（生产必备）：

```java
// 简易实现：继承 ThreadPoolExecutor 暴露统计信息
public class MonitoredPool extends ThreadPoolExecutor {
    public MonitoredPool(int core, int max, long keepAlive, TimeUnit unit,
                          BlockingQueue<Runnable> queue) {
        super(core, max, keepAlive, unit, queue);
    }
    // 定时调用 getActiveCount() / getQueue().size() / getCompletedTaskCount()
// 活跃数接近上限 + 队列堆积 => 需要扩容或限流
```

**判断线程池是否该扩**：队列长期非空 + 活跃线程数打满 ⇒ 吞吐已到瓶颈；队列长期为空 + 活跃数远低于核心数 ⇒ 核心数设大了。

**最重要的实践**：**不要用 `Executors`**，永远显式 `new ThreadPoolExecutor` 并指定有界队列 + 明确的拒绝策略。同时记住：线程池里的任务如果持有 ThreadLocal、数据库连接、文件句柄，必须在任务内部用 try-finally 清理，否则线程复用会把资源泄漏到下一个任务。
