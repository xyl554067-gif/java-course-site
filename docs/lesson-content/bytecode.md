## 本节要点

Java 的「一次编译，到处运行」靠的是**字节码**：源码编译成与平台无关的 class 文件，由各平台的 JVM 解释或 JIT 编译成机器码。class 文件是一套严格定义的二进制格式，方法执行的核心单位是**栈帧**。

## 核心概念

- **字节码（Bytecode）**：中间指令集，与平台无关，是 JVM 的输入。
- **class 文件结构**：以 u1/u2/u4/u8 描述的二进制格式，依次是魔数、版本号、常量池、访问标志、类/接口定义、字段表、方法表、属性表。
- **常量池**：class 文件的「资源仓库」，存放字面量与符号引用，是索引化的（类似数组而非 Map）。
- **方法表中的 Code 属性**：局部变量表、操作数栈、异常表、LineNumberTable 等。
- **栈帧（Stack Frame）**：每次方法调用创建，包含局部变量表、操作数栈、动态链接、方法引用、返回地址。
- **操作数栈**：JVM 的计算核心，字节码指令直接操作它。
- **执行引擎**：解释器（逐条解释，慢）+ JIT（热点代码编译成本地代码，快）。
- **即时编译器**：C1（Client，编译快、优化少）+ C2（Server，优化深），分层编译按调用次数与热度选择。

## 关键代码

```java
// 方法调用对应的栈帧压栈与出栈
void caller() {
    int a = add(1, 2);   // 压入 caller 栈帧 → 调用 add（新建栈帧）→ 返回后弹出
    System.out.println(a);
}

int add(int x, int y) {
    // add 的栈帧：局部变量表含 x、y；操作数栈存放运算中间结果
    return x + y;
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为"一次编译到处运行"是 JVM 逐条解释执行，实际热点代码会被 JIT 编译成本地代码
- 混淆「栈帧」与「线程栈」——线程栈是栈帧的容器
- 认为局部变量表在方法执行完还能访问，它的作用域仅限当前栈帧
- 以为 `int` 参数传的是值、`String` 参数传的是引用，实际所有参数都是值传递

## 动手练习

用 `javap -c -v` 反编译一个方法，逐行对照字节码与栈帧中局部变量表、操作数栈的变化。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《doocs-jvm》《深入理解 Java 虚拟机（第 3 版）》《二哥的 JVM 进阶之路》对本节有系统覆盖。

**class 文件结构的字段宽度**

《doocs-jvm》给出了「u2、u4、u8 分别代表……」的说明，这是读懂 class 文件格式的必备前提：

| 类型 | 字节 | 典型用途 |
| --- | --- | --- |
| u1 | 1 | 魔数部分、access_flags |
| u2 | 2 | minor/major 版本号、常量池数量、字段/方法数量、属性长度 |
| u4 | 4 | 常量池索引、字段名索引、属性名索引 |
| u8 | 8 | CONSTANT_Long、CONSTANT_Double 的实际值 |

class 文件的整体布局（依据《doocs-jvm》）：

```
ClassFile {
    u4 magic;                 // 0xCAFEBABE
    u2 minor_version, major_version;
    u2 constant_pool_count;
    cp_info constant_pool[];  // 常量池，第 1 项有效
    u2 access_flags;
    u2 this_class, super_class;
    u2 interfaces_count; u2 interfaces[];
    u2 fields_count; field_info fields[];
    u2 methods_count; method_info methods[];
    u2 attributes_count; attribute_info attributes[];
}
```

**常量池是 class 文件的核心**

《doocs-jvm》指出常量池里存了两类东西：**字面量**（如字符串、整数常量）与**符号引用**（字段/方法/类的符号引用）。符号引用在解析阶段被替换为直接引用，这正是「动态链接」的含义——运行时才知道要调用哪个方法的具体地址。

**字节码指令的分类**

《深入理解 Java 虚拟机（第 3 版）》第 6 章专门讲字节码指令，可归纳为 8 类：

- 加载与存储：`iload`、`aload`、`istore`、`astore`
- 运算：`iadd`、`isub`、`imul`、`idiv`、`irem`
- 类型转换：`i2l`、`i2d`、`d2i`
- 对象与数组：`new`、`getfield`、`putfield`、`newarray`、`arraylength`
- 控制转移：`ifeq`、`if_icmpeq`、`goto`、`tableswitch`、`lookupswitch`
- 返回：`ireturn`、`areturn`、`return`
- 方法调用：`invokevirtual`、`invokestatic`、`invokeinterface`、`invokedynamic`
- 异常处理：`athrow`、`catch`（通过异常表实现）

其中 `tableswitch` 与 `lookupswitch` 是 `switch` 编译后的两种形式：前者用于 case 连续、后者用于 case 稀疏。

**invokedynamic 与 Lambda**

知识库中《深入浅出 Java + 23 种设计模式》与《二哥的 Java 进阶之路》都在讲 Lambda 与函数式接口时提到 `invokedynamic`。它是 JDK 7 引入的指令，用于在运行期决定调用哪个方法——Lambda 表达式正是靠它在运行期生成实现类并绑定方法引用，这是「Lambda 不产生额外类文件」的技术原因。

**栈帧的结构**

《深入理解 Java 虚拟机（第 3 版）》给出的栈帧结构是：

| 局部 | 说明 |
| --- | --- |
| 局部变量表 | 存储方法参数与局部变量，以 slot 为单位，`long`/`double` 占 2 个 slot |
| 操作数栈 | 字节码指令的工作区，最大深度由 `max_stack` 指定 |
| 动态链接 | 指向运行时常量池的方法引用 |
| 方法引用 | 指向方法本身 |
| 返回地址 | 恢复调用者的 pc |

局部变量表中的 slot 复用是常见考点：一个方法内多个局部变量可以共用同一个 slot（前提是作用域不重叠），这让 `javap -l` 输出的 LocalVariableTable 看起来"槽位"比变量少。

## 实战提示

看懂字节码的实用场景：

```bash
# 反编译方法字节码与局部变量表
javap -c -l -p MyClass.class

# 只看某个方法
javap -c MyClass.class | sed -n '/void foo()/,/^$/p'
```

最常用来解决三类问题：

1. **确认泛型擦除的实际结果**——`List<String>` 与 `List<Integer>` 在字节码层面签名相同
2. **理解 lambda 的实现**——看 `invokedynamic` 的 bootstrap 方法指向哪个 `LambdaMetafactory`
3. **验证编译器优化**——如字符串拼接在 `invokedynamic` 下会被编译成 `StringConcatFactory.makeConcatWithConstants`，比老版本的 StringBuilder 拼接更高效

另外注意：`javap` 显示的是**逻辑结构**，而 `javap -v` 加上 `Code` 属性的字节码反汇编才能看到真实指令序列。配合 `-l` 看 LocalVariableTable，才能把指令与源码变量一一对应。
