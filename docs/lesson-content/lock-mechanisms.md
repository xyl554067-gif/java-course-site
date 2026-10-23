## 本节要点

`synchronized` 是 JVM 层面的monitor（管程），靠对象头里的锁状态标志实现锁升级；`ReentrantLock` 是 JUC 的显式锁，底层基于 AQS 的 CAS。两者都可重入，区别在于后者支持**公平锁、可中断、超时获取、多条件变量**。

## 核心概念

- **monitorenter / monitorexit**：字节码指令，对应同步代码块与同步方法。
- **锁状态标志**：对象头 Mark Word 中的几位，标记无锁 → 偏向锁 → 轻量级锁 → 重量级锁。
- **锁升级（膨胀）**：无锁 → 偏向锁（已废弃）→ 轻量级锁（CAS 自旋）→ 重量级锁（操作系统互斥锁）。**只能升级不能降级**。
- **轻量级锁**：用 CAS + 自旋实现，不涉及内核态切换，适合「多线程交替执行」的低竞争场景。
- **重量级锁**：竞争激烈时膨胀为 monitor，线程进入 BLOCKED 状态，由 OS 负责调度。
- **AQS（AbstractQueuedSynchronizer）**：JUC 同步器的骨架，用一个 volatile int state 表示同步状态 + 一个 CLH 变体的双向队列管理等待线程。
- **CAS（Compare And Swap）**：无锁并发的基础，`compareAndSet` 原子更新。
- **公平锁 vs 非公平锁**：公平锁按队列 FIFO 获取锁，非公平锁允许刚到位的线程"插队"（tryAcquire 的实现差异）。
- **可重入**：同一线程可重复获取同一把锁（重入计数）。
- **Condition**：每个 Lock 可new 出多个条件队列，比 `Object.wait/notifyAll` 更精确。

## 关键代码

```java
// synchronized：同步代码块（锁对象）与同步方法（锁 this）
Object lock = new Object();
synchronized (lock) {
    // 临界区
}

public synchronized void method() {
    // 锁的是 this
}

// ReentrantLock：手动加解锁，必须放在 finally 里
private final ReentrantLock lock = new ReentrantLock();

void safeMethod() {
    lock.lock();
    try {
        // 临界区
    } finally {
        lock.unlock();     // 忘记 unlock 会导致死锁
    }
}

// 公平锁 + 可中断获取
private final ReentrantLock fair = new ReentrantLock(true);
try {
    if (fair.tryLock(1, TimeUnit.SECONDS)) {
        try { /* 业务 */ } finally { fair.unlock(); }
    }
} catch (InterruptedException e) {
    Thread.currentThread().interrupt();   // 恢复中断标志
}

// 多条件变量：队列非空 / 队列非满
private final Condition notEmpty = lock.newCondition();
private final Condition notFull = lock.newCondition();
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 `synchronized` 一定会膨胀到重量级锁——低竞争下只用轻量级锁，几乎无开销
- 认为 `ReentrantLock` 一定比 `synchronized` 快——性能取决于竞争程度
- 忘记 `unlock()` 或把 `unlock()` 写在 `try` 块内
- 认为 `wait/notify` 必须配合 `synchronized`，其实必须配合**同一个监视器对象**
- 在 `synchronized` 块里调用外部方法，怕「业务方也加锁」导致死锁

## 动手练习

用 `jstack` 观察一个因锁竞争进入 BLOCKED 状态的线程栈，分析它卡在哪个 monitor 上。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《深入理解高并发编程（第 2 版）》《二哥的并发编程进阶之路》《极致经典（卷 1/2/3）：Java 高并发核心编程》《面渣逆袭Java并发编程》对本节有深入覆盖。

**synchronized 的锁对象**

《深入理解 JVM 核心技术》给出一条关键规则：「普通同步方法，锁是当前实例对象锁」。完整的锁对象表：

| 同步形式 | 锁对象 |
| --- | --- |
| 同步实例方法 | `this` |
| 同步静态方法 | `Class` 对象（`Class.forName("X").class`） |
| 同步代码块 | `synchronized(...)` 括号里指定的对象 |
| 同步方法（可重入） | 同一线程可再次进入，计数 +1 |

**锁升级路径**

知识库中《二哥的 JVM 进阶之路》与《深入浅出 Java 多线程》都覆盖了锁升级。要点：

- **无锁 → 偏向锁**：只有一个线程访问时，把线程 ID 写入 Mark Word，后续该线程访问无需 CAS。JDK 15 起偏向锁被废弃（JEP 374），JDK 18 彻底移除。
- **偏向锁 → 轻量级锁**：出现第二个线程访问时，撤销偏向锁，升级为轻量级锁。
- **轻量级锁 → 重量级锁**：自旋超过阈值（默认 10 次 / 20 次自旋，JDK 6 后自适应）仍获取不到，则膨胀为重量级锁。

**自适应的自旋**：JDK 6 引入。自旋次数由「最近一次成功获取锁的线程是否很快释放」决定，避免「刚释放就要等线程切换」的开销。

**AQS 与两种锁的实现差异**

《深入理解高并发编程（第 2 版）》与《二哥的并发编程进阶之路》都指出：「锁、非公平锁底层采用 AQS 实现」。AQS 的核心结构：

```java
private volatile int state;                 // 同步状态
private volatile Node head, tail;           // CLH 双向队列
```

`ReentrantLock` 的两种获取方式正是公平性的分水岭：

| 方法 | 行为 |
| --- | --- |
| `lock()` | 公平锁：先 `hasQueuedPredecessors()` 判断队列中是否有前驱；非公平锁：直接 `tryAcquire` 抢占 |
| `tryLock()` | 两种锁都是直接尝试一次，失败立即返回 false，不排队 |

非公平锁的"插队"就发生在 `tryAcquire` 里：即使队列里有人在等，只要当前线程能 CAS 成功就立刻拿到锁。**默认使用非公平锁**，因为公平锁的线程切换开销大，吞吐明显更低。

**ReentrantLock 的额外能力**

知识库中《面渣逆袭Java并发编程》对比了 `synchronized` 与 `ReentrantLock`：

| 能力 | synchronized | ReentrantLock |
| --- | --- | --- |
| 公平性 | 只能非公平 | 可选 |
| 可中断获取 | 否 | `lockInterruptibly()` |
| 超时获取 | 否 | `tryLock(timeout)` |
| 多条件变量 | 否（只有 wait/notifyAll） | `newCondition()` 多个 |
| 必须在 finally 解锁 | 自动 | 手动 |

**wait / notifyAll 与 Condition**

《深入浅出 Java 多线程-RedSpider》"基础篇"第 5 章讲线程间通信。`Object.wait()` 的三个约束：

1. 必须在 `synchronized` 块中调用
2. 必须持有该监视器的锁
3. 唤醒方必须是**同一个监视器**上的 `notify`/`notifyAll`

`Condition` 是 AQS 提供的替代方案，每个条件有独立的等待队列，唤醒更精准。典型用法是阻塞队列：

```java
// 生产者：队列满则等待 notFull
while (queue.size() == capacity) notFull.await();
// 消费者：队列空则等待 notEmpty
while (queue.isEmpty()) notEmpty.await();
```

**避免死锁的工程实践**

《面试题-04-并发编程面试题》给出的死锁四个必要条件中，最实用的是打破**循环等待条件**——全局固定加锁顺序：

```java
// 所有地方都按 userId -> orderId 的顺序加锁，杜绝交叉
synchronized (userMap.get(userId)) {
    synchronized (orderMap.get(orderId)) {
        // ...
    }
}
```

## 实战提示

选型建议：

| 场景 | 选择 |
| --- | --- |
| 简单同步、临界区短 | `synchronized`（JVM 优化后零额外开销） |
| 需要超时/中断/公平/多条件 | `ReentrantLock` |
| 单写多读、读远多于写 | `ReadWriteLock` |
| 无锁计数、状态机 | `AtomicInteger` / `LongAdder` |

排查锁问题的实用手段：

```bash
# 看哪些线程 BLOCKED
jstack <pid> | grep -B 5 -A 15 "BLOCKED"

# 看锁竞争情况（JDK 8+）
jcmd <pid> Thread.print -l
```

`synchronized` 锁在 JDK 15+ 已被**重新实现**（JEP 374 移除偏向锁），不再是「对象头写线程 ID」的老实现，而是用 **Lightweight Lock（-thin lock）** 在对象头上直接记录持锁线程，膨胀时再转成 monitor。这让无竞争场景下的同步开销降到接近于零。
