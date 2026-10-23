## 本节要点

HashMap = **数组 + 链表 + 红黑树**。`hash()` 做扰动把冲突降到最低，`putVal` 走「空桶直接放 / 桶内有 key 则覆盖 / 否则挂链表或树化」三条路径。链表长度 ≥ 8 且数组长度 ≥ 64 时转红黑树。

## 核心概念

- **DEFAULT_CAPACITY = 16**：默认初始容量。
- **LOAD_FACTOR = 0.75**：负载因子，元素数 > capacity × 0.75 时扩容。
- **TREEIFY_THRESHOLD = 8**：链表长度达 8 转红黑树。
- **UNTREEIFY_THRESHOLD = 6**：树缩回链表的阈值（留 2 的缓冲避免反复转换）。
- **MIN_TREEIFY_CAPACITY = 64**：数组容量不足 64 时优先扩容而非树化。
- **hash() 扰动函数**：`h ^ (h >>> 16)`，让高 16 位参与低位运算。Java 8 之前是 `h ^ (h >>> 20) ^ (h >>> 12)`，因为 HashMap 用 `h & (n-1)` 取模，只用到了低位。
- **扩容**：容量翻倍为 2 的幂，取模可以用位运算 `& (n-1)` 替代 `%`。
- **红黑树化**：解决链表过长导致的 O(n) 查找，主要对抗恶意哈希碰撞。
- **节点类型**：链表节点 `Node`，树节点 `TreeNode`（多了 parent/left/right/prev）。

## 关键代码

```java
// 核心参数
static final int DEFAULT_CAPACITY = 16;
static final float LOAD_FACTOR = 0.75f;
static final int TREEIFY_THRESHOLD = 8;    // 链表长度 ≥8 转红黑树
static final int UNTREEIFY_THRESHOLD = 6;  // 树缩回链表的阈值

// 为什么阈值是 8：泊松分布下冲突到 8 的概率极低，
// 正常情况链表很短，转树主要是为了对抗恶意构造的哈希碰撞

// 扰动函数：让高位也参与定位
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 HashMap 是绝对线程安全的，并发下会成环导致 CPU 100%
- 只记「冲突转红黑树」却不知道为什么阈值是 8
- 以为 `HashMap` 有序——它完全无序，需要有序用 `LinkedHashMap` 或 `TreeMap`
- 在并发场景直接用 `HashMap`，JDK 7 会成环，JDK 8 虽不死循环但仍会丢数据

## 动手练习

构造一组 key，让 hashCode 只差 1，插入 10 个观察链表是否树化（需包级访问或反射）。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《二哥的 Java 进阶之路暗黑版》《面渣逆袭 Java 集合框架篇》《面试题-02-Java集合容器面试题》《深入理解高并发编程（第 2 版）》对本节覆盖最详尽。

**putVal 的三条路径**

《二哥的 Java 进阶之路》把 `putVal` 的逻辑拆得很清楚：

1. **桶为空** → 直接 new Node 放入（无锁竞争时用 CAS）
2. **桶内首节点 hash 匹配且 key 相同**（`==` 或 `equals`）→ 覆盖 value
3. **否则** → 挂到链表尾部；若链表长度 ≥ 8 且表长 ≥ 64 → 树化；树中同样先查 key 再插入

注意第 3 步在 JDK 8 中要**先判断树化条件中的表长**：表长 < 64 时调用 `resize()` 扩容而非树化，因为小表扩容比树化更划算。

**红黑树的转换条件与过程**

《深入理解高并发编程（第 2 版）》与《二哥的 Java 进阶之路》都给出了「转换为红黑树链表转换为红黑树过程」：

- **树化阈值 8**：为什么不是 7 或 9？泊松分布下，桶中元素达到 8 个的概率约为千万分之六，正常使用几乎不可能触发。树化主要针对**恶意构造的哈希碰撞攻击**——攻击者可以构造出所有 key 落同一桶的数据集，把查找退化成 O(n)。
- **退化阈值 6**：树缩回链表需要 ≥ 6，因为扩容时链表可能被拆成两段（树化会保持相对顺序），若阈值与 8 太近会导致转换抖动。
- **表长门槛 64**：数组小的时候，桶多、每个桶的元素少，扩容比树化成本低。

**扩容机制与高位参与**

《面渣逆袭 Java 集合框架篇》与《二哥的 Java 进阶之路》解释了为什么容量必须是 2 的幂，以及 JDK 8 的优化：

- 容量为 2 的幂 → `hash & (n-1)` 等价于取模，但快得多
- JDK 7 扩容时需要**重算每个 key 的 hash**（`h ^ (h >>> 20) ^ (h >>> 12)`），因为新旧容量取模结果不同
- JDK 8 保留每条链表的**相对顺序**，扩容时按原索引拆成 lo/hi 两条链，无需重算 hash

JDK 8 的 `hash()` 简化成 `h ^ (h >>> 16)`，正是为了让高 16 位参与低位运算，**保证扩容后 hash & (newCap-1) 与 hash & (oldCap-1) 结果相同的那一位**。

**ConcurrentHashMap 的扩容控制**

《深入理解高并发编程（第 2 版）》提到「ConcurrentHashMap 扩容操作控制」——JDK 8 的 ConcurrentHashMap 在扩容时采用**协助扩容**机制：某个线程发现要扩容，就标记 `transfer` 状态并推进一个 transferIndex，其他线程发现自己也在扩容且未参与，就会协助搬运桶。这比 JDK 7 的分段锁扩容高效得多。

**get 方法的遍历顺序**

《面渣逆袭 Java 集合框架篇》指出 `get` 的查找顺序是：先查数组槽 → 若为红黑树节点则走 `find` → 否则遍历链表。并强调 **HashMap 的 key 应同时重写 hashCode 与 equals**，只重写 equals 会导致两个"逻辑相等"的 key 落到不同桶，get 找不到。

**面试高频结论**

《面试题-02-Java集合容器面试题》给出的对比结论：

| | HashMap | LinkedHashMap | TreeMap |
| --- | --- | --- | --- |
| 底层 | 数组+链表+红黑树 | 数组+链表+红黑树+双链表 | 红黑树 |
| 顺序 | 无序 | 插入序 / 访问序 | key 排序 |
| 查找 | O(1) | O(1) | O(log n) |
| 是否允许 null key | 允许 1 个 | 允许 1 个 | **不允许** |
| 线程安全 | 否 | 否 | 否 |

## 实战提示

**为什么 key 要用不可变对象**：

HashMap 会用 `hashCode()` 定位桶、用 `equals()` 判断是否为同一个 key。如果 key 在放入 Map 后被修改（导致 hashCode 变化），你就再也找不到它了——数据"人间蒸发"。所以 key 应当是 String、Integer 这类不可变对象。

**并发场景的正确选择**：

```java
// 需要并发读写
ConcurrentHashMap<String, Integer> map = new ConcurrentHashMap<>();

// 或者用 ConcurrentHashMap.newKeySet() 替代 HashSet
Set<String> set = ConcurrentHashMap.newKeySet();
```

**排查哈希冲突**：用 `-Djdk.map.althashing.threshold=1`（JDK 8u191+）把树化阈值降到 1，便于快速复现树化路径；或直接用 JOL/反射观察 `table` 数组结构。

**性能提示**：初始化时预估容量，避免多次扩容：

```java
// 预知会放 1000 个元素：new HashMap<>(1000 / 0.75 + 1)
Map<String, Object> map = new HashMap<>(1334);
```

因为扩容不仅耗时，还会**打散原有的链表顺序**（JDK 8 保留相对顺序，但桶位置变了），影响缓存命中率。
