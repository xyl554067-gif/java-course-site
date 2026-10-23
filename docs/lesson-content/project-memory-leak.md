## 本节要点

内存泄漏的本质是：**本该被回收的对象仍然可达**。排查要回答两个问题——哪些对象没被回收（dump 分析），以及为什么没被回收（GC Roots 路径分析）。常见的元凶是静态集合、监听器、ThreadLocal 与未关闭的连接。

## 核心概念

- **内存泄漏 vs 内存溢出**：泄漏是「占用持续增长且无法回收」的现象，溢出（OOM）是「申请内存超出上限」的结果。
- **静态集合**：最常见的泄漏源。`static` 集合随类加载器存活，只要类不被卸载，元素就永远可达。
- **ThreadLocal**：线程池中的线程复用，ThreadLocalMap 里的 value 只有 remove 才会清。
- **监听器/回调未注销**：注册进长生命周期对象（容器、静态集合）后不反注册。
- **未关闭的连接**：JDBC Connection、文件流、Socket 占着堆外内存与 native 资源。
- **类加载器泄漏**：动态生成的类无法卸载（元空间泄漏），Tomcat 热部署常见。
- **dump 分析三板斧**：Leak Suspects → Dominator Tree → Path to GC Roots。

## 关键代码

```java
// 泄漏复现：静态集合持有对象引用，GC 无法回收
public class LeakDemo {
    // 静态集合 —— 类加载器级别存活，里面的东西永远可达
    private static final List<Object> CACHE = new ArrayList<>();

    public static void leak() {
        for (int i = 0; i < 10000; i++) {
            CACHE.add(new byte[1024 * 1024]);   // 每次 1MB
        }
    }
}

// 正确写法：用 WeakReference 观察回收（配合 -XX:+PrintReferenceGC）
WeakReference<byte[]> ref = new WeakReference<>(new byte[1024 * 1024]);
System.gc();
Thread.sleep(100);
System.out.println(ref.get() == null ? "已回收" : "仍可达");
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 OOM 就一定是堆太小，其实元空间溢出、线程创建失败都与堆大小无关
- 靠"重启就好了"掩盖问题，泄漏源没找到下次还会复发
- 误用 `System.gc()` 作为"解决方案"，它只是提示，还会带来额外停顿
- 认为 WeakReference 能解决所有泄漏，它只解决"引用关系"造成的泄漏，解决不了"业务上仍然需要"的强引用

## 动手练习

写一个模拟静态集合泄漏的程序，用 `jcmd <pid> GC.heap_dump` 抓快照，在 MAT 中找出 dominator 最大的对象并定位其 GC Root 路径。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面渣逆袭 JVM》《深入理解 Java 虚拟机（第 3 版）》《面试题-08-Java虚拟机(JVM)面试题》以及《Java多线程开发最佳实践手册》对本节给出了完整的排查视角。

**内存泄漏与内存溢出的关系**

《面试题-08-Java虚拟机(JVM)面试题》把这两个问题放在一起对比：

- 「内存溢出异常」——「Java 会存在内存泄漏吗？请简单描述」
- 「Java 会存在内存泄漏吗？」的答案：**内存泄漏是指内存空间被占满却无法回收**，持续累积最终导致 OOM

知识库中列举的典型泄漏场景：

1. **静态集合**：往静态 List/Map 里塞对象且不清理
2. **监听器**：注册了监听器但没有反注册
3. **连接未关闭**：数据库连接、流、Socket
4. **ThreadLocal**：线程池复用线程时 value 残留
5. **缓存无淘汰策略**：Map 无限增长

**类型卸载与类加载器泄漏**

《doocs-jvm》指出方法区回收的目标之一是**对类型的卸载**，而卸载需要三个条件同时满足：类的所有实例都被回收、加载它的 ClassLoader 被回收、Class 对象没被引用。

这条链在容器环境里格外重要——《二哥的 JVM 进阶之路》与《深入浅出 Java 多线程》都提到自定义类加载器的生命周期管理。Tomcat 中每个 Web 应用有独立 ClassLoader，若应用中有大量动态代理、脚本引擎或频繁热部署，ClassLoader 无法被回收 ⇒ 对应的元空间也无法回收 ⇒ `OutOfMemoryError: Metaspace`。

**并发场景下的泄漏源**

《Java多线程开发最佳实践手册》覆盖了线程创建与生命周期管理、同步机制、JUC 工具、线程池配置优化、CompletableFuture 异步编程等 30 多个实战示例，其中线程池相关的实践正是泄漏高发区：

```java
// 错误：ThreadLocal 未 remove，线程复用导致 value 残留
private static final ThreadLocal<UserContext> CTX = new ThreadLocal<>();
// ... 使用 CTX.set(user)
executor.submit(() -> {
    UserContext ctx = CTX.get();   // 拿到的是上一个任务残留的！
});

// 正确：finally 中清理
executor.submit(() -> {
    try {
        CTX.set(user);
        // 业务逻辑
    } finally {
        CTX.remove();
    }
});
```

**排查工具链**

《JVM 调优工具》与《二哥的 JVM 进阶之路》覆盖的工具正好构成本节的实操路径：

- `jstat -gcutil <pid> 1000` — 观察老年代是否持续增长
- `jcmd <pid> GC.heap_dump /path/heap.hprof` — 抓堆快照（比 `jmap` 更安全）
- `jstack <pid>` — 看线程是否卡在某个对象上

**软引用、弱引用与缓存**

《面渣逆袭Java并发编程》与《面渣逆袭 Java 集合框架篇》在讲缓存实现时对比了三种引用：

| 引用 | 回收时机 | 典型用途 |
| --- | --- | --- |
| 强引用 | 永不回收 | 普通对象 |
| 软引用 | 内存不足时回收 | 内存敏感的数据缓存 |
| 弱引用 | 下次 GC 必定回收 | 规范化的 canonical 映射 |
| 虚引用 | 不决定生命周期 | 堆外内存管理 |

做缓存时，若用强引用 + 无淘汰策略，就是一个必然会 OOM 的设计。

## 实战提示

一套可复用的排查流程：

```bash
# 1. 观察增长趋势（连续观察，确认是"持续增长"而非波动）
jstat -gcutil <pid> 1000

# 2. 确认老年代在涨
jstat -gc <pid> 1000 | awk '{print "OU="$9" OC="$10" YGC="$13" FGC="$15}'

# 3. 抓快照（在 OOM 前抓，或配 -XX:+HeapDumpOnOutOfMemoryError 自动抓）
java -XX:+HeapDumpOnOutOfMemoryError -jar app.jar
# 产出 java_pid<pid>.hprof
```

MAT 中：`Leak Suspects Report` 先看自动分析 → `Dominator Tree` 按 Retained Heap 排序找大头 → 右键选 `Path to GC Roots > exclude weak references`，看它被谁引用着。

**关键判据**：如果 dominator 最大的对象是 `HashMap$Node[]` 或 `byte[]`，去查是不是有静态集合或无界缓存；如果看到大量 `Class` 对象实例，怀疑类加载器泄漏或动态代理滥用；如果 dominator 是 `ThreadLocal$ThreadLocalMap`，查 `remove()` 是否遗漏。

**预防比排查更重要**：能用自动装配管理的对象不要手写 new；缓存一定要有容量上界与淘汰策略；ThreadLocal 必须在 `finally` 里 remove；所有资源用 try-with-resources。
