## 本节要点

数组是**定长**的同类元素容器，声明时类型就固定了。关键点：数组是引用类型（可以赋给 Object）、长度不可变、多维数组本质是「数组的数组」、数组元素没有类型安全检查（可存 null 与任意子类型）。

## 核心概念

- **定长**：创建后长度不可变，扩容需新建数组并拷贝。
- **数组是引用类型**：`int[] a = new int[3]` 分配的是**引用**（对象），不是数组本身。
- **默认值**：数值 0、char `\u0000`、boolean false、引用 null。
- **数组变量 vs 数组对象**：`int[] a = new int[3]` 中 a 是引用，指向数组对象。
- **一维数组**：连续内存，元素按下标访问 O(1)。
- **多维数组**：`int[][] a = new int[2][3]` 实际是「一个长度为 2 的数组，每个元素是长度为 3 的数组」。**外层可为空，内层不可**（`new int[2][]` 合法但 `new int[2][3]` 不合法时内层不可 null 访问）。
- **Arrays 工具类**：sort、binarySearch、copyOf、fill、equals、hashCode、stream。
- **数组协变**：`Object[] arr = new String[1]` 合法，但 `arr[0] = 1` 会抛 ArrayStoreException。
- **数组的 clone()**：浅拷贝（对基本类型是深拷贝，对引用元素是浅拷贝）。
- **变长参数**：`void f(int... args)` 编译为 `void f(int[] args)`。
- **数组不是泛型**：不能 `List<int>`，但可以用 `List<Integer>` 或 `Arrays.asList` 包装。
- **Arrays.asList 的固定长度**：返回的是视图，不能 add/remove。

## 关键代码

```java
// 声明与初始化
int[] a = new int[3];                    // 默认全 0
int[] b = {1, 2, 3};                     // 简洁写法
int[] c = new int[]{1, 2, 3};

// 数组是引用类型
Object[] obj = new String[2];            // 数组协变，合法
obj[0] = "str";
// obj[1] = 123;                        // ArrayStoreException

// 长度不可变 —— 扩容要新建
int[] big = Arrays.copyOf(a, 10);

// 二分查找（必须先排序）
int[] sorted = {1, 3, 5, 7, 9};
Arrays.sort(sorted);
int idx = Arrays.binarySearch(sorted, 5);   // 2

// 填充与比较
Arrays.fill(sorted, 0);
boolean same = Arrays.equals(new int[]{1,2}, new int[]{1,2});

// 克隆：基本类型是深拷贝
int[] orig = {1, 2, 3};
int[] copy = orig.clone();
copy[0] = 99;
System.out.println(orig[0]);             // 1 —— 不受影响

// 多维数组
int[][] grid = new int[2][3];
grid[0][1] = 5;
System.out.println(grid.length);         // 2  —— 外层长度
System.out.println(grid[0].length);      // 3  —— 内层长度

// 变长参数
static int sum(int... nums) {
    int s = 0;
    for (int n : nums) s += n;
    return s;
}
sum(1, 2, 3);
sum();                     // 空数组

// 数组 → List
List<Integer> list = Arrays.asList(1, 2, 3);   // 固定长度视图
// list.add(4);                               // UnsupportedOperationException
List<Integer> mutable = new ArrayList<>(Arrays.asList(1, 2, 3));

// 数组流
int[] nums = {1, 2, 3, 4};
Arrays.stream(nums).sum();
int[] evens = Arrays.stream(nums).filter(n -> n % 2 == 0).toArray();
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 `int[] a = new int[3]` 直接分配了 3 个 int 的空间——先分配引用（数组对象），元素在堆上
- 多维数组 `arr.length` 取到的是元素个数而非总元素数
- 用 `Arrays.asList` 的结果调用 add/remove
- 以为 `arr[0] = null` 对基本类型数组合法——编译报错
- 混淆 `clone()` 的深浅拷贝
- 二分查找前忘记排序

## 动手练习

实现一个二维数组的矩阵乘法，并对比用三重循环与用 Stream 的可读性差异。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Java编程思想第四版》《面渣逆袭 Java 基础篇》《二哥修订版《30天速通Java》暗黑版》《面试题-01-Java基础知识面试题》《hello-algo_1.2.0_zh_java.pdf》对本节有覆盖。

**《Java编程思想第四版》第 8 章：数组**

这本书把数组与「类型安全」作为核心议题，指出 Java 数组的最大特点是**类型安全且自动检查**（对比 C/C++）：

- 数组只能是单一类型的对象或基本类型
- 编译器确保数组里装的元素类型正确
- 但数组**不是泛型**——`List<int>` 非法，只能用 `List<Integer>`

书中指出数组的**协变**特性：

```java
Object[] objects = new String[2];   // 合法
objects[0] = new Integer(1);        // 运行时 ArrayStoreException
```

**为什么会有协变**：Java 的类型转换规则允许子类数组向上转型为父类数组（类似协变返回类型），代价是失去了编译期的完全检查。

**《Java编程思想第四版》第 11 章：数组的初始化**

书中指出「数组本质上就是一组相同类型的变量」，而**基本类型数组与对象数组的内存布局不同**：

- `int[]`：连续存放 int 值，无对象头
- `Integer[]`：连续存放**引用**，每个 Integer 对象另占内存

因此在处理大量数字时，`int[]` 比 `Integer[]` 省内存得多。书中给出的替代方案是 `ArrayList` 的特化版本 `IntArrayList`（Guava 提供）。

**可变参数的实现**

《面渣逆泽 Java 基础篇》与《二哥修订版《30天速通Java》暗黑版》指出：

```java
void f(int... args) { }
// 编译后等价于
void f(int[] args) { }
```

调用 `f(1, 2, 3)` 时编译器会**新建一个数组**再传入——所以可变参数在高频调用路径上有额外开销，且**只能出现在参数列表的最后**。

**Arrays 工具类**

《java实战演练35讲》与《二哥修订版《30天速通Java》暗黑版》都强调两个常用方法：

```java
// 二分查找：前提是已排序
int[] arr = {1, 3, 5, 7, 9};
Arrays.sort(arr);
int i = Arrays.binarySearch(arr, 7);      // 3

// copyOf：扩容并保留原内容
int[] bigger = Arrays.copyOf(arr, 10);    // 后 5 个为 0
```

**《hello-algo》对数组的定位**

《hello-algo_1.2.0_zh_java》（算法教程）把数组定位为「最基础的数据结构」，并强调：

- 数组元素在内存中**连续存放**，支持随机访问（O(1)）
- 但「在中间插入/删除」需要移动后续元素，代价 O(n)
- 因此**查找用数组、插入删除用链表**是经典权衡

这解释了为什么 Java 集合框架里 ArrayList 与 LinkedList 都要有。

**数组排序**

《面渣逆袭 Java 基础篇》指出 `Arrays.sort` 对基本类型与对象的行为不同：

```java
int[] nums = {5, 2, 8};
Arrays.sort(nums);                       // 双轴快排（基本类型）

String[] names = {"pear", "apple"};
Arrays.sort(names);                     // 对象数组：调用 compareTo（TimSort）
Arrays.sort(names, (a, b) -> a.length() - b.length());   // 自定义比较器
```

**对象数组排序依赖 Comparable/Comparator**，这也是 Collections.sort 的实现基础。

**数组的浅拷贝问题**

《面渣逆袭Java基础篇V2.0（暗黑）》指出：

```java
int[][] matrix = {{1, 2}, {3, 4}};
int[][] copy = matrix.clone();     // 浅拷贝！
copy[0][0] = 99;
System.out.println(matrix[0][0]); // 99 —— 内层数组是共享的
```

深拷贝需要逐层克隆或用 `Arrays.deepToString` / `deepEquals` 系列方法。

**《面试题-01-Java基础知识面试题》的数组考点**

同一份资料把数组相关的考点归纳为：

- 数组的定义与初始化方式
- 数组的默认值
- 数组的长度（length 属性，不可改变）
- 数组的遍历方式（for / for-each / Arrays.stream）
- 数组排序与查找
- 二维数组的定义与遍历
- 数组与集合的转换

**数组与集合的转换**

《二哥修订版《30天速通Java》暗黑版》与《面渣逆袭 Java 基础篇》给出双向转换：

```java
// 数组 → List
List<String> list = Arrays.asList(arr);            // 固定长度视图
List<String> list2 = new ArrayList<>(Arrays.asList(arr));   // 可变副本
List<String> list3 = Arrays.stream(arr).toList();  // Java 16+，不可变

// List → 数组
String[] arr2 = list.toArray(new String[0]);
String[] arr3 = list.toArray(String[]::new);        // 推荐的写法

// 基本类型数组 → 流
int[] nums = {1, 2, 3};
int sum = Arrays.stream(nums).sum();
```

## 实战提示

**数组选型建议**：

| 需求 | 选择 |
| --- | --- |
| 元素类型固定、数量已知、追求性能 | 数组 |
| 需要动态增删 | ArrayList |
| 大量数字、内存敏感 | 基本类型数组 |
| 需要泛型 | List\<T\>（用包装类型） |

**常见陷阱清单**：

```java
// 1. 数组长度是属性不是方法
int len = arr.length;      // ✔ 没有括号

// 2. 基本类型数组不能存 null
// int[] a = {1, null};    // 编译错误

// 3. 遍历时修改长度会异常
for (int i = 0; i < arr.length; i++) {
    arr = Arrays.copyOf(arr, arr.length + 1);   // 危险！length 被重新求值
}

// 4. 多维数组要逐层判空
if (grid != null && grid[0] != null) { ... }
```

**性能提示**：数组是 JVM 优化最好的容器——访问可以完全消除边界检查（前提是循环边界已知）。因此在超热路径上，数组往往比 List 更快。

**但要注意**：Java 的 `List.remove(int)` 与 `List.remove(Object)` 重载差异是新手 bug 高发地——`list.remove(1)` 删的是**下标 1**，不是值为 1 的元素。数组没有这个问题，这也是数组更"安全"的一个理由。
