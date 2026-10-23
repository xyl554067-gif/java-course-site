## 本节要点

JVM 调优有两把钥匙：**GC 日志**告诉你「发生了什么」，**线程栈/堆快照**告诉你「为什么」。工具链上，`jstat` 看趋势、`jmap` 打快照、`jstack` 看线程、`jcmd` 聚合入口、`jconsole`/`VisualVM` 做可视化。

## 核心概念

- **jstat**：按指定间隔输出类加载、垃圾回收、编译、运行时内存等统计，是排查「内存是否泄漏」的第一站。
- **jmap**：生成堆转储（dump）、打印类信息、统计实例。是分析对象占用的核心工具。
- **jstack**：打印各线程的堆栈快照，定位死锁、线程卡死、CPU 飙高。
- **jcmd**：JDK 7+ 的统一诊断入口，`jcmd <pid> help` 列出全部能力。
- **GC 日志**：JDK 9+ 统一为 `-Xlog:` 语法，是判断停顿原因最直接的证据。
- **OOM 三类**：堆溢出、元空间溢出、线程创建失败——定位路径完全不同。
- **堆转储分析**：MAT / VisualVM 看 dominator tree，能直接指出「谁占着内存」。

## 关键代码

```java
// 运行时取堆信息（代码内诊断用）
Runtime rt = Runtime.getRuntime();
long total = rt.totalMemory() / 1024 / 1024;   // 已分配
long free  = rt.freeMemory()  / 1024 / 1024;   // 空闲
long max   = rt.maxMemory()   / 1024 / 1024;   // 上限
System.out.printf("堆: %dM/%dM (上限 %dM)%n", total - free, total, max);

// 线程数
Thread.activeCount();

// 可达性分析辅助：主动触发一次 GC 再观察回收效果
System.gc();
Thread.sleep(200);
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 `System.gc()` 能可靠触发 Full GC，它只是一个提示，多数实现会直接忽略
- 只看 Heap Used 就下结论"内存泄漏"，实际要看对象数量与 dominator tree
- 用 `kill -9` 抓 dump，导致 dump 文件不完整无法分析
- 认为调大堆就能解决所有 OOM，元空间与线程的问题跟堆大小无关

## 动手练习

用 Arthas 的 dashboard 命令观察进程运行状态，并尝试用 trace 命令观察某个方法的耗时分布。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《JVM 调优工具》《二哥的 JVM 进阶之路》《深入理解 Java 虚拟机（第 3 版）》对本节工具链有直接覆盖。

**jstat 各选项的用途**

《JVM 调优工具》开篇就给出了 jstat 的常用命令，是本节最直接的操作依据：

```bash
# 合并显示各列
jstat -gc <pid> 1000

# 只看 GC 相关的列（更清爽）
jstat -gcutil <pid> 1000
```

jstat 输出的关键列：

| 列 | 含义 | 怎么看 |
| --- | --- | --- |
| S0C / S1C / EC | 两个 Survivor 与 Eden 的容量（KB） | 反映新生代大小配置 |
| OU / OC | 老年代使用量 / 容量 | 持续增长 → 老年代泄漏 |
| YGC / YGCT | Young GC 次数 / 总耗时 | 频率过高 → 分配速率太快 |
| FGC / FGCT | Full GC 次数 / 总耗时 | **只要有就要查原因** |
| GCCS | GC 后使用量 | 与 OU 对比可判断回收是否有效 |

《JVM 调优工具》特别强调用 `jstat -gcutil` 时关注各列的**比率**（如 O、YGC 的变化趋势），比看绝对值更能反映问题。

**jstack 与线程状态**

《二哥的 JVM 进阶之路》与《深入浅出 Java 多线程》都涉及线程 dump 的分析。jstack 输出中每个线程都带状态标记，排查时的关注点：

- `BLOCKED` → 死锁或锁竞争（看 `-Deadlock` 段落）
- `WAITING (on object monitor)` → 等待释放锁
- `RUNNABLE` 且 CPU 占用高 → 用 `top -H -p <pid>` 找到线程 ID，再 `jstack | grep <tid>` 定位
- `TIMED_WAITING` 且在 `Thread.sleep` → 正常的定时任务

**死锁的四个必要条件**

《面试题-04-并发编程面试题》把「什么是线程死锁，形成死锁的四个必要条件」列为高频题：

1. 互斥条件
2. 不可剥夺条件
3. 持有并等待条件
4. 循环等待条件

打破任一条件即可避免死锁，实践中最常用的是「**按固定顺序加锁**」来破坏循环等待条件。

**内存泄漏与内存溢出的区别**

《面试题-08-Java虚拟机(JVM)面试题》与《面渣逆袭 JVM》都明确区分了这两个概念：

- **内存泄漏**：内存占用持续增长，GC 无法回收，最终 OOM。是**现象**
- **内存溢出（OOM）**：分配内存时超出可用上限。是**结果**

典型泄漏源（知识库中《面渣逆袭 JVM》与《面渣逆袭 Java 集合框架篇》都提到）：

- 静态集合持有对象引用（最常见）
- 监听器注册后未注销
- 线程池中的 ThreadLocal 未 remove
- 连接未关闭（数据库、文件流）

## 实战提示

一套标准的线上排查流程：

```bash
# 1. 确认内存趋势
jstat -gcutil <pid> 1000

# 2. 抓线程栈（CPU 高时抓 3 次，间隔 5 秒，对比）
jstack <pid> > thread1.txt

# 3. 抓堆快照（OOM 前抓，或用 jcmd 更安全）
jcmd <pid> GC.heap_dump /tmp/heap.hprof

# 4. 查 GC 日志
jcmd <pid> GC.heap_info
```

MAT 中打开 hprof 后，第一步看 **Leak Suspects Report**，第二步看 **Dominator Tree** 按 Retained Heap 排序—— dominator 最大的那个对象就是泄漏源头。第三步用 **Path to GC Roots** 找出它为什么没被回收。

排查 CPU 飙高则是另一条路径：`top -H -p <pid>` 拿到占用最高的线程 TID（十进制转十六进制）→ `jstack` 里 grep 该 nid → 找到具体方法栈。

**关于 Arthas**：知识库中《二哥的 JVM 进阶之路》的《Java多线程开发实战手册》提到过它。相比命令行工具，Arthas 的 `dashboard`、`thread -n 3`、`trace`、`watch` 让排查过程无需重启进程，在生产环境更适合；但它自身有性能开销，压测环境需谨慎开启。
