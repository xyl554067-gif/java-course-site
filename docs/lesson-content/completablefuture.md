## 本节要点

`CompletableFuture` 是 Java 8 引入的异步编排工具，用**回调 + 依赖**的方式替代 `Future.get()` 的阻塞等待。它支持串行依赖、并行执行、异常兜底与超时控制。

## 核心概念

- **核心思想**：把「等待结果」变成「拿到结果后继续做什么」。任务完成即回调，不阻塞线程。
- **静态工厂**：`supplyAsync`（有返回值）、`runAsync`（无返回值）。
- **默认线程池**：`ForkJoinPool.commonPool()`，是 JVM 共享的公共池。**生产环境要显式指定业务线程池**。
- **串行依赖**：`thenApply`（转换）、`thenAccept`（消费）、`thenRun`（不关心结果）。
- **扁平化组合**：`thenCompose`（返回 CompletableFuture 时用它，避免嵌套 Future）。
- **并行 + 汇聚**：`allOf`（全部完成，返回 void）、`anyOf`（任一完成）。
- **异常处理**：`exceptionally`（只处理异常）、`handle`（无论成败都执行）、`whenComplete`（观察但不改变结果）。
- **超时控制**：`orTimeout`（超时抛 TimeoutException）、`completeOnTimeout`（超时给默认值）。
- **手动完成**：`complete` / `completeExceptionally`，用于「外部回调驱动」的场景。
- **注意**：`thenApply` 等方法在**上一步的线程**上执行；`thenApplyAsync` 在新线程（可指定 Executor）。

## 关键代码

```java
// 串行：查询 -> 转换 -> 消费
CompletableFuture.supplyAsync(() -> queryUser(id))
        .thenApply(User::getName)
        .thenAccept(name -> log.info("name={}", name))
        .exceptionally(ex -> {
            log.error("查询失败", ex);
            return null;
        });

// 扁平化：避免 Future<Future<T>> 嵌套
CompletableFuture.supplyAsync(() -> queryUser(id))
        .thenCompose(user -> queryOrders(user.getId()));

// 并行 + 汇聚
CompletableFuture<String> a = CompletableFuture.supplyAsync(() -> "A");
CompletableFuture<String> b = CompletableFuture.supplyAsync(() -> "B");
CompletableFuture.allOf(a, b).thenRun(() -> {
    System.out.println(a.join() + b.join());
});

// 异常处理：handle 能拿到异常也能拿到结果
CompletableFuture.supplyAsync(() -> mayFail())
        .handle((r, ex) -> ex != null ? "fallback" : r);

// 超时
CompletableFuture.supplyAsync(() -> slowCall())
        .orTimeout(3, TimeUnit.SECONDS)
        .exceptionally(ex -> "timeout");

// 显式指定线程池（生产必做）
ExecutorService bizPool = Executors.newFixedThreadPool(8);
CompletableFuture.supplyAsync(() -> heavyIo(), bizPool);
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 用 `CompletableFuture.supplyAsync` 不传 Executor，导致业务任务挤占 `ForkJoinPool.commonPool()`，与全局 `parallelStream` 抢资源
- 在 `thenApply` 里做耗时操作——它跑在上一个任务的线程上，会拖慢那个线程
- 以为 `exceptionally` 能捕获 `thenApply` 内部抛出的异常（可以，但 `handle` 语义更清晰）
- 忽略 `join()` 与 `get()` 的区别：`join` 抛非受检 `CompletionException`，`get` 抛受检 `InterruptedException` / `ExecutionException`
- 没有兜底：任一环节异常会导致整条链静默结束，必须挂 `exceptionally` / `handle`

## 动手练习

用 `CompletableFuture` 并行调用三个模拟接口，聚合结果后统一返回，并给整体加 2 秒超时与降级兜底。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《极致经典（卷 1/2/3）：Java 高并发核心编程》《Java多线程开发最佳实践手册》《深入理解高并发编程（第 2 版）》《实战高并发设计模式》对本节覆盖非常细致。

**thenCompose 的定位**

《极致经典（卷 2）》第 10.2.4 节专门讲「thenCompose() 方法」，这正是 CompletableFuture 家族最容易搞混的一组方法：

| 方法 | 上一阶段返回 | 何时用 |
| --- | --- | --- |
| `thenApply` | 普通值 T | 简单转换，T → U |
| `thenAccept` | 普通值 T | 只消费，不产出 |
| `thenRun` | 普通值 T | 不关心结果 |
| `thenCompose` | `CompletableFuture<U>` | **扁平化**，避免 `CF<CF<U>>` 嵌套 |

《极致经典（卷 3）》与《卷 1》都提到「异步回调模式」是 CompletableFuture 的核心价值——它把传统的「阻塞等待结果」变成「结果到达后触发回调」，让线程不被占着。

**默认线程池的风险**

《Java多线程开发最佳实践手册》在"CompletableFuture 异步编程"一节明确指出默认行为的问题：`supplyAsync` / `runAsync` 不传 Executor 时使用 `ForkJoinPool.commonPool()`。这个池是**全 JVM 共享**的：

- 它的并行度默认是 `CPU 核数 - 1`
- 所有未指定 Executor 的 CompletableFuture、以及 `parallelStream()` 都会用它
- 一旦某个任务阻塞（IO 等待），整个公共池可能被打满，**影响毫不相关的业务**

正解是显式传业务线程池。

**任务编排模式**

《实战高并发设计模式》第 4.2 节讲「任务编排」，《深入理解高并发编程（第 2 版）》提到「使用 CompletableFuture 来优化」这类场景。典型编排模式：

```java
// 顺序执行（串行依赖）
CompletableFuture.supplyAsync(this::stepA)
        .thenCompose(r -> CompletableFuture.supplyAsync(() -> stepB(r)))
        .thenAccept(this::stepC);

// 并行执行后聚合
CompletableFuture<String> userF = fetchUser();
CompletableFuture<List<Order>> orderF = fetchOrders();
userF.thenCombine(orderF, (u, os) -> merge(u, os))
     .thenAccept(this::save);
```

`thenCombine` 是两个**已有** CompletableFuture 的组合，`thenCompose` 是「上一个产出的 CF 再接下一个」。

**异常处理的三个方法**

《Java多线程开发最佳实践手册》对异常处理给了明确分工：

| 方法 | 何时执行 | 是否改变结果 |
| --- | --- | --- |
| `exceptionally` | 仅异常时 | 用返回值替换异常 |
| `handle` | 无论成败 | 用返回值替换结果或异常 |
| `whenComplete` | 无论成败 | **不改变**结果，仅做观察/日志 |

实践建议：链尾统一挂一个 `handle` 兜底，中间的异常让它自然向下传播。

**异步转同步的场景**

《从零开始手写 RPC 框架》提到「异步转同步」这个经典问题——框架内部用异步模型，但对外暴露同步接口。典型实现是「一个 Future + 一个阻塞等待的队列」：

```java
// 思路：异步执行 + CountDownLatch 等待
CountDownLatch latch = new CountDownLatch(1);
CompletableFuture.runAsync(() -> {
    try {
        doWork();
    } finally {
        latch.countDown();
    }
});
latch.await();
```

**超时与降级**

《Java多线程开发实战手册》强调生产环境必须为每个异步链路设超时，否则下游卡住会一路传导把上游线程池打满：

```java
// 超时抛异常
future.orTimeout(2, TimeUnit.SECONDS)
// 超时给默认值（降级）
future.completeOnTimeout("default", 2, TimeUnit.SECONDS)
```

## 实战提示

**生产环境的三条铁律**：

1. **永远显式传 Executor**，不要用公共池
2. **链尾永远挂兜底**，避免异常被静默吞掉
3. **每个异步链路都要有超时**，防止故障扩散

```java
private static final ExecutorService BIZ_POOL = Executors.newFixedThreadPool(
        Runtime.getRuntime().availableProcessors() * 2,
        new ThreadPoolExecutor.CallerRunsPolicy(),
        new ThreadPoolExecutor.AbortPolicy());   // 满时直接失败，配合上游重试

public <T> CompletableFuture<T> call(Supplier<T> supplier, long timeoutMs) {
    return CompletableFuture.supplyAsync(supplier, BIZ_POOL)
            .orTimeout(timeoutMs, TimeUnit.MILLISECONDS)
            .handle((r, ex) -> {
                if (ex != null) {
                    log.warn("异步调用失败", ex);
                    throw new CompletionException(ex);
                }
                return r;
            });
}
```

**注意线程池隔离**：不同业务用不同池，避免慢任务拖垮快任务。ThreadPoolExecutor 按业务维度划分（如 `orderPool`、`queryPool`）是常见做法。

**`join` vs `get`**：

| | `join()` | `get()` |
| --- | --- | --- |
| 抛出的异常 | `CompletionException`（非受检） | `ExecutionException`（受检） |
| 可中断 | 否 | 是（抛 `InterruptedException`） |
| 用在哪 | Lambda 表达式里 | 需要响应中断的地方 |

在 `thenApply` 的 lambda 里用 `join()` 更方便，因为受检异常没法在函数式接口里传。
