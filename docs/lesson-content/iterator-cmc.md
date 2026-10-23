## 本节要点

迭代器的 fail-fast 机制靠 `modCount` 实现：集合每次结构性修改都递增它，迭代器创建时记录快照，遍历中若发现不一致就抛 `ConcurrentModificationException`。这是**尽力而为的错误检测**，不是并发安全保证。

## 核心概念

- **Iterator 接口**：四个方法 `hasNext()`、`next()`、`remove()`。
- **modCount**：ArrayList / HashMap 等的字段，记录结构性修改次数。
- **expectedModCount**：迭代器创建时记录的快照值。
- **fail-fast**：遍历中检测到 modCount 变化立即抛 CME，**尽早暴露 bug**，而不是继续遍历出不确定结果。
- **结构性修改**：改变元素个数或顺序的操作（add/remove/clear）。**修改元素内容不算**（如 `list.set(0, x)` 不触发）。
- **ConcurrentModificationException**：fail-fast 的载体，是**运行时异常**（非受检）。
- **CopyOnWriteArrayList 的迭代器**：**快照式**，遍历时不抛 CME，但也不反映后续修改。
- **弱一致性迭代器**：ConcurrentHashMap 的迭代器，弱一致（可能看到也可能看不到并发修改），但不抛 CME。
- **removeIf 的正确性**：`Collection.removeIf` 默认实现用迭代器，安全；ArrayList 覆写了它做批量优化。

## 关键代码

```java
List<String> list = new ArrayList<>(List.of("a", "b", "c"));
Iterator<String> it = list.iterator();
while (it.hasNext()) {
    String s = it.next();
    if (s.equals("b")) list.remove(s);   // 直接改集合 → fail-fast
}

// 正确做法：用迭代器自身的 remove()
it = list.iterator();
while (it.hasNext()) {
    if (it.next().equals("b")) it.remove();
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 遍历时用集合自身的 remove/delete 导致 CME，其实应用迭代器的 remove
- 给 CopyOnWriteArrayList 频繁写入，数组全量复制导致性能极差
- 认为 CME 是"并发导致的异常"——它其实是**单线程写错了**的信号
- 认为 `set` 也会触发 CME——修改内容不改结构，不触发

## 动手练习

复现一次 ConcurrentModificationException，再用迭代器 remove 修正，对比结果。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Java编程思想第四版》《面渣逆袭 Java 集合框架篇》《二哥的 Java 进阶之路》对本节有深入论述。

**fail-fast 的实现原理**

《Java编程思想第四版》第 11 章给出了 fail-fast 的源码级解释：

```java
public Iterator<E> iterator() {
    return new Itr();   // Itr 是 ArrayList 的内部类
}

private class Itr implements Iterator<E> {
    int expectedModCount = modCount;   // 快照
    ...
    public E next() {
        checkForComodification();       // 每次 next 都校验
        ...
    }
    final void checkForComodification() {
        if (modCount != expectedModCount)
            throw new ConcurrentModificationException();
    }
}
```

**《Java编程思想第四版》特别强调：fail-fast 只是一项「尽力而为」的服务，JDK 承诺尽力检测并发修改，但不保证一定检测到。** 也就是说：CME 出现说明一定有并发修改，但没出现不代表没有并发修改。

**结构性修改的定义**

《二哥的 Java 进阶之路》与《面试题-02-Java集合容器面试题》都列出了哪些操作会触发 modCount 变化：

| 操作 | 是否结构性修改 |
| --- | --- |
| `add` / `remove` / `clear` / `addAll` / `removeAll` / `retainAll` | ✔ 是 |
| `set(index, e)` | ✘ 否（只改内容） |
| `sort` / `replaceAll` | ✘ 否（不改变元素个数） |

注意 `sort` 虽然不改变 modCount，但它会改变元素顺序——这正是 fail-fast 的一个**盲区**：排序后继续遍历可能读到"错位"的数据却不报错。

**CopyOnWriteArrayList 的快照迭代器**

《面渣逆袭 Java 集合框架篇》指出 CopyOnWriteArrayList 的迭代器持有的是**创建迭代器那一刻**的数组快照：

```java
public Iterator<E> iterator() {
    return new COWIterator<>(getArray());   // 传入当前数组的引用
}
```

这带来两个特性：
1. 遍历中修改集合**不会抛 CME**（迭代器看不到变化）
2. 迭代器**看不到**创建之后的修改

所以 CopyOnWriteArrayList 适合「注册监听器列表」这类读多写少的场景，而不是需要实时一致性的场景。

**ConcurrentHashMap 的弱一致迭代器**

《二哥的 Java 进阶之路》与《面渣逆袭 Java 集合框架篇》指出，ConcurrentHashMap 的迭代器是**弱一致（weakly consistent）**的：

- 遍历过程中若有并发修改，迭代器可能看到、也可能看不到被修改的元素
- 但**不会抛 CME**，也不会导致无限循环
- 这是为了保证遍历效率——若采用 fail-fast，就要给每次遍历加全局锁

**增强 for 与迭代器的等价关系**

《Java编程思想第四版》明确指出增强 for 循环编译后就是 Iterator 循环，因此**在增强 for 里删除元素同样会 CME**：

```java
for (String s : list) {
    if (s.isEmpty()) list.remove(s);   // CME！
}
```

**并发集合与 fail-fast 的取舍**

《面渣逆袭 Java 集合框架篇》给出结论：并发集合选择**弱一致性**而非 fail-fast，因为在真实并发场景下，「检测到并发修改就抛异常」几乎无法恢复——你无法通过捕获 CME 来安全地继续处理。弱一致性牺牲了实时准确性，换来的是可用的并发语义。

## 实战提示

**按条件删除的三种正确写法**：

```java
// 1. removeIf（推荐，内部用迭代器，无 CME 风险）
list.removeIf(s -> s.isEmpty());

// 2. 迭代器 remove
Iterator<String> it = list.iterator();
while (it.hasNext()) {
    if (it.next().isEmpty()) it.remove();
}

// 3. Java 8 的 replaceAll + removeIf 组合
list.replaceAll(s -> s.trim());
list.removeIf(String::isEmpty);
```

**注意 `remove` 的重载陷阱**：

```java
list.remove(1);          // 删除下标 1 的元素（int）
list.remove(Integer.valueOf(1));  // 删除值为 1 的元素
```

传 `int` 字面量永远走下标重载。删除元素一律用 `removeIf` 或 `remove(Object)`（显式装箱）。

**CME 的正确处理方式**：它不是"偶发异常可以 catch 掉重试"——catch 之后继续遍历仍然是不确定的。正确做法是**改写代码**，不要 catch CME。

**排查 CME 的思路**：

1. 看堆栈里 `checkForComodification` 的调用位置
2. 确认是不是在遍历时调用了集合的增删方法（包括间接的，如 `list.forEach(x -> list.remove(...))`）
3. 若是并发场景，改用并发集合（ConcurrentHashMap / CopyOnWriteArrayList）
