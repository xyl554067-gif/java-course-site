## 本节要点

线程是 CPU 调度的最小单位。Java 提供四种创建方式，但推荐 `Runnable` 或线程池。线程有六种状态，转换由 `Thread` 的方法驱动。并发编程要守住三个要素：**原子性、可见性、有序性**。

## 核心概念

- **并发 vs 并行**：并发是「同一时刻多个任务交替推进」，并行是「同一时刻多个任务真正同时执行」。单核靠时间片轮转实现并发，多核才能真正并行。
- **线程 vs 进程**：进程是资源分配的基本单位，线程是 CPU 调度的基本单位。同一进程的线程共享堆、方法区，但各自持有栈和程序计数器。
- **四种创建方式**：`Thread` 子类、`Runnable`、`Callable`+`FutureTask`、`线程池`。后两者可返回结果、可抛异常。
- **六种状态**：NEW、RUNNABLE、BLOCKED、WAITING、TIMED_WAITING、TERMINATED。注意 RUNNABLE 同时包含 OS 层面的就绪与运行两种状态。
- **上下文切换**：线程从 CPU 上换下再换上，代价与栈深度成正比。
- **原子性**：操作不可被中断。`i++` 实际是「读—改—写」三步，不是原子的。
- **可见性**：一个线程的修改对其他线程可见。需靠 `volatile` / 同步机制保证。
- **有序性**：程序执行顺序不因编译器/CPU 重排而改变。
- **守护线程**：不影响 JVM 退出（GC 线程、IO 线程）。用户线程结束即触发 JVM 退出。

## 关键代码

```java
// 方式一：Runnable（推荐，无返回值但无继承耦合）
new Thread(() -> System.out.println("hello")).start();

// 方式二：Callable + FutureTask（有返回值、可抛受检异常）
FutureTask<String> task = new FutureTask<>(() -> "result");
new Thread(task).start();
System.out.println(task.get());   // 阻塞等待结果

// 线程状态
Thread t = new Thread(() -> { });
System.out.println(t.getState()); // NEW
t.start();
Thread.sleep(100);
// t.getState() 此时通常是 RUNNABLE 或 TIMED_WAITING

// 守护线程
Thread daemon = new Thread(() -> {
    try {
        while (true) Thread.sleep(1000);
    } catch (InterruptedException ignored) { }
});
daemon.setDaemon(true);
daemon.start();
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 Runnable 比 Callable"低效"，实际只是不能返回值与抛受检异常
- 以为调用 `t.start()` 两次会报异常，它会抛 `IllegalThreadStateException`
- 把「线程.sleep」当作让出 CPU 的正确手段，它只是让当前线程进入 TIMED_WAITING
- 以为线程数越多越快，上下文切换的开销可能适得其反

## 动手练习

用 `Thread.getState()` 打印一个线程从创建到结束的全部状态转换，观察线程在 WAITING 与 RUNNABLE 之间切换。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭Java并发编程》《面试题-04-并发编程面试题》《深入浅出 Java 多线程-RedSpider》《Java多线程开发实战手册》《由浅入深Java并发》对本节覆盖非常完整。

**并发编程三要素**

《面试题-04-并发编程面试题》开篇即列出「并发编程三要素是什么？」：

1. **原子性**：一个操作不可被中断，要么全执行要么全不执行
2. **可见性**：一个线程修改了变量，其他线程能立即看到
3. **有序性**：程序的执行顺序不会被重排打乱

并在「在 Java 程序中怎么保证多线程的运行安全？」中给出解法映射：原子性靠 CAS / 锁，可见性靠 `volatile` / 锁，有序性靠 `volatile` 的内存屏障。

**并发 vs 并行的图示**

《面渣逆袭Java并发编程》用一张图区分二者：并行是同一时刻两个线程都在执行（需要两个 CPU）；并发是同一时刻只有一个在执行，但一段时间内两个都执行过。**并发的实现依赖于 CPU 切换线程，因为切换时间特别短，用户基本无感知。**

**死锁的四个必要条件**

同一份资料详细列出了死锁条件与规避方式：

1. 互斥条件
2. 不可剥夺条件
3. 持有并等待条件
4. 循环等待条件

「如何避免线程死锁」的工程做法：**破坏循环等待条件**——所有线程按全局固定顺序获取锁。

**创建线程的四种方式与 Runnable / Callable 的区别**

《面试题-04》对比了两者：Runnable 没有返回值、不能抛受检异常；Callable 有泛型返回值、可以抛异常、还能通过 FutureTask 拿到结果。实践中 `Runnable` 更常用（配合线程池），需要结果时才用 `Callable`。

**Java 线程与操作系统线程的关系**

《深入理解高并发编程：核心原理与案例实战》的思维导图第 1 章第 1.4 节专门讲「Java 线程与操作系统线程的关系」，同时覆盖了：

- 冯诺依曼计算机模型与 CPU 架构
- 单核 CPU 的不足、多核 CPU 架构、多 CPU 架构
- 用户级线程、内核级线程、混合级线程三种模型

Java 采用的是**一对一映射**（一个 Java 线程对应一个 OS 线程），因此线程创建、销毁成本较高——这正是线程池存在的根本原因。

**线程状态与线程优先级**

《深入浅出 Java 多线程-RedSpider》的目录显示其"基础篇"第 3 章讲线程组与线程优先级，第 4 章讲「Java 线程的状态及主要转化方法」，第 5 章讲线程间通信。它把线程状态分为 6 种：

| 状态 | 含义 |
| --- | --- |
| NEW | 尚未启动 |
| RUNNABLE | 在 JVM 中正在执行（含 OS 就绪） |
| BLOCKED | 等待获取 synchronized 锁 |
| WAITING | 无限期等待（Object.wait、Thread.join） |
| TIMED_WAITING | 限期等待（sleep、wait(timeout)） |
| TERMINATED | 已终止 |

**守护线程与用户线程**

同一份资料指出：守护线程是为辅助服务用户线程而存在的，其生命周期依附于用户线程，**用户线程结束，守护线程随之结束**。典型守护线程有垃圾回收线程、编译器线程等。

**查找高 CPU 线程的方法**

《面试题-04》还提到「如何在 Windows 和 Linux 上查找哪个线程 CPU 利用率最高？」，这在实战排查中非常有用：

```bash
# Linux：top -H 找出线程级 CPU 占用最高的 TID
top -H -p <pid>
# 转成十六进制后在 jstack 里匹配 nid
printf '%x\n' <tid>
jstack <pid> | grep -A 20 '<nid>'
```

## 实战提示

线程数不是越多越好。经验公式：

- **CPU 密集型**（计算、加解密、压缩）：线程数 ≈ 核数 + 1
- **IO 密集型**（数据库、RPC、文件）：线程数 ≈ 核数 × (1 + 等待时间/计算时间)

《Java多线程开发实战手册》在"线程池配置优化"一节给出的思路正是如此：先压测确定基线，再按任务类型调整，而不是拍脑袋给一个 200。

另一个容易被忽略的细节：**不要在持锁期间调用可能阻塞或耗时长的操作**（如远程调用、打印日志）。这既是死锁的高发原因，也让锁的粒度白白变大。
