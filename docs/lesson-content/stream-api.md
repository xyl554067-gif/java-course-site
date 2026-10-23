## 本节要点

Stream 把集合操作从「描述怎么做」变成「描述要什么」。核心特征是**惰性求值**——中间操作只构建流水线，真正干活的是终端操作。`Collectors` 承担了分组、聚合、汇总三大职责。

## 核心概念

- **Stream 不是集合**：不存储数据，是数据处理的视图。
- **惰性求值**：中间操作（filter/map/sorted/limit）返回新 Stream，不立即执行；只有终端操作（collect/forEach/count/anyMatch）触发真正的遍历。
- **流只能消费一次**：终端操作后流就关闭了，再用会抛 `IllegalStateException`。
- **中间操作**：filter、map、flatMap、distinct、sorted、limit、skip、peek。
- **终端操作**：collect、forEach、reduce、count、min/max、anyMatch/allMatch/noneMatch、findFirst/findAny。
- **Collectors**：groupingBy（分组）、partitioningBy（按布尔分组）、toMap、counting、summing、averaging、joining、summarizing、mapping、collectingAndThen。
- **短路操作**：findFirst、anyMatch、limit、takeWhile——找到结果即停止。
- **并行流**：使用 ForkJoinPool.commonPool()，适合纯计算、大数据量、无共享状态。
- **peek 的陷阱**：只有终端操作执行后 peek 才会真正跑，调试时容易误判。

## 关键代码

```java
List<Order> orders = getOrders();

// 分组统计：每个用户的订单数和总金额
Map<Long, Stats> stats = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId,
            Collectors.collectingAndThen(
                    Collectors.toList(),
                    list -> new Stats(list.size(), list.stream()
                            .mapToDouble(Order::getAmount).sum()))));

// filter 中有状态且已并行时才有意义
orders.parallelStream()
    .filter(o -> o.getAmount() > 100)
    .map(Order::getUserName)
    .forEach(System.out::println);
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 在 Stream 里做副作用操作（println、修改外部变量），破坏可读性
- 对数据量小的集合用并行流，线程调度开销反而更慢
- 以为 `peek` 是"调试专用"，其实它是有副作用的操作，只是常用于调试
- 在终端操作之前多次调用 `filter` 后以为会重复遍历——惰性求值下只遍历一次

## 动手练习

把一个订单列表按用户分组，输出每个用户的订单数与总金额。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《二哥的 Java 进阶之路暗黑版》《深入理解高并发编程（第 2 版）》《Java多线程开发最佳实践手册》《面渣逆袭Java并发编程》对本节的方法论有支撑。

**Stream 的惰性求值与流水线**

《二哥的 Java 进阶之路暗黑版》与《深入理解高并发编程（第 2 版）》都强调 Stream 的处理链路是**惰性**的：

```
数据源 → filter → map → sorted → collect
         ↑ 中间操作只构建流水线，不执行
                                   ↑ 终端操作触发一次性遍历
```

这个模型解释了几个现象：

- `stream().filter(...)` 之后不做终端操作，**什么都不会发生**
- 一个流只能被消费一次，因为终端操作会关闭它
- `sorted()` 在并行流中开销大——它必须**收集全部元素后排序**（有状态操作需要完整缓冲区）

**Collectors 的分组能力**

《二哥的 Java 进阶之路》与《面渣逆袭Java并发编程》都演示了 groupingBy 的三种形式：

```java
// 1. 按 key 分组，value 是列表
Map<Long, List<Order>> byUser = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId));

// 2. 分组后立即汇总（下游收集器）
Map<Long, Long> countByUser = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId, Collectors.counting()));

// 3. 分组 + 映射 + 汇总（组合下游）
Map<Long, Double> sumByUser = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId,
            Collectors.summingDouble(Order::getAmount)));

// 按布尔分区（两桶，key 固定为 true/false）
Map<Boolean, List<Order>> big = orders.stream()
    .collect(Collectors.partitioningBy(o -> o.getAmount() > 100));
```

**toMap 的两个坑**

《二哥的 Java 进阶之路》特别提醒 `Collectors.toMap` 的两个问题：

```java
// 坑1：value 为 null 会抛 NPE
Collectors.toMap(Order::getId, Order::getRemark)   // remark 为 null → NPE

// 解决：用 merge 的三参数版本
Collectors.toMap(Order::getId, Order::getRemark, (a, b) -> a)

// 坑2：key 重复会抛 IllegalStateException
Collectors.toMap(Order::getUserId, Order::getId)  // 同用户多单 → 异常
```

**下游收集器（Downstream Collector）**

《深入理解高并发编程（第 2 版）》与《Java多线程开发最佳实践手册》都介绍了 `collectingAndThen` 的组合模式：

```java
// 先收集，再对结果做一次转换
Map<Long, String> userNames = orders.stream()
    .collect(Collectors.groupingBy(Order::getUserId,
            Collectors.collectingAndThen(
                    Collectors.mapping(Order::getUserName, Collectors.toList()),
                    names -> String.join(",", names))));
```

**并行流与 Collectors 的线程安全**

《Java多线程开发最佳实践手册》指出，并行流中 Collectors 的实现必须**线程安全**——JDK 提供的实现（`toList`、`groupingBy`）都用了并发容器合并结果，但自定义 Collector 时必须自己保证 `combiner()` 的正确性：

```java
// 自定义 Collector 的 combiner 负责合并两个分片的结果
Collector<Order, ?, Map<Long, List<Order>>> myCollector =
    Collector.of(
        ArrayList::new,                 // supplier
        (list, o) -> list.add(o),       // accumulator
        (l1, l2) -> { l1.addAll(l2); return l1; },  // combiner（并行必需）
        Collector.Characteristics.IDENTITY_FINISH);
```

**Stream 与循环的取舍**

《二哥的 Java 进阶之路》与《深入浅出Java+23种设计模式》都提到 Stream 的真正价值在**可读性**而非性能：

- 简单遍历：for 循环更直白
- 多步变换 + 聚合：Stream 表达力明显更强
- 需要索引、break、continue：Stream 不便（用 `findFirst` / `takeWhile` 替代）

## 实战提示

**Collectors 全景速查**：

| 用途 | 方法 |
| --- | --- |
| 转集合 | `toList()` / `toSet()` / `toCollection(LinkedHashSet::new)` |
| 分组 | `groupingBy` / `partitioningBy` |
| 映射 | `mapping` |
| 计数 | `counting()` |
| 求和 | `summingInt/Double/Long` |
| 平均 | `averagingInt/Double/Long` |
| 最值 | `maxBy` / `minBy` |
| 汇总统计 | `summarizingInt/Double/Long`（含 count/sum/min/max/avg） |
| 拼接 | `joining(delimiter, prefix, suffix)` |
| 转换后汇总 | `collectingAndThen` |

**调试 Stream 的正确方式**：

```java
// peek 必须在终端操作之前，否则不会执行
list.stream()
    .peek(s -> System.out.println("处理: " + s))
    .filter(s -> s.length() > 3)
    .collect(Collectors.toList());
```

`peek` 的位置很关键——放在 `filter` 之前看到的是全部元素，放在之后只看到通过过滤的元素。

**并行流的判断标准**：

| 场景 | 建议 |
| --- | --- |
| 纯计算 + 数据量大（>10万）+ 无共享状态 | 用并行流 |
| 涉及 IO / 远程调用 | 用 CompletableFuture + 独立线程池 |
| 数据量小（<1万） | 串行更快 |
| 操作有副作用（写数据库、打印） | **不要并行**（顺序不确定） |

**性能陷阱**：并行流下 `Collectors.toList()` 虽安全但有额外开销；数据量不大时并行流普遍比串行慢。真正需要性能时用 JMH 测量，而不是凭感觉。

**Stream 的短路能力常被忽视**：

```java
// 遇到第一个满足条件就停 —— 大数据量下能省大量计算
Optional<Order> first = orders.stream()
    .filter(o -> o.getAmount() > 10000)
    .findFirst();

// Java 9+ 的 takeWhile：遇到不满足就停（与 filter 的区别）
List<Order> prefix = orders.stream()
    .takeWhile(o -> o.getAmount() > 100)   // 遇到 <=100 立即停止
    .collect(Collectors.toList());
```
