## 本节要点

类的生命周期要经历七个阶段：加载 → 验证 → 准备 → 解析 → 初始化 → 使用 → 卸载，其中前五个构成类加载过程。核心机制是**双亲委派模型**：类加载请求先委派给父加载器，父加载器无法完成才由自己加载。

## 核心概念

- **加载（Loading）**：通过全限定名获取二进制字节流 → 定义为运行时数据区结构 → 生成 Class 对象。
- **验证（Verification）**：确保字节码符合规范，不会危害虚拟机安全，且不会破坏正确性。
- **准备（Preparation）**：为类变量分配内存并设置初始值。注意：这里的「初始值」是**零值**（int 为 0、引用为 null），不是源码里的赋值表达式。
- **解析（Resolution）**：把常量池中的符号引用替换为直接引用（可以延后到真正使用时）。
- **初始化（Initialization）**：执行类构造器 `<clinit>`，按源码顺序执行静态变量赋值与静态代码块。
- **双亲委派模型**：Bootstrap → Extension → Application → 自定义，先问父，父不行才自己干。
- **破坏双亲委派**：SPI、OSGi、热部署都依赖自定义 ClassLoader 打破委派顺序。
- **类加载的时机**：首次主动使用（new、访问静态字段、反射、初始化子类等）时加载；解析可延后。

## 关键代码

```java
// 双亲委派：先问父加载器，父搞不定才自己加载
protected Class<?> loadClass(String name, boolean resolve) {
    Class<?> c = findLoadedClass(name);
    if (c == null) {
        try {
            c = parent.loadClass(name, false);   // 1. 父加载器
        } catch (ClassNotFoundException e) {
        }
        if (c == null) c = findClass(name);      // 2. 自己加载
    }
    return c;
}
// 破坏双亲委派：SPI、OSGi、热部署都靠自定义 ClassLoader
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 以为 `Class.forName` 一定初始化类，其默认不会执行静态块
- 把类名写错导致 ClassNotFoundException，却以为是包路径问题
- 认为「准备阶段会给静态变量赋源码里的值」，其实准备阶段赋的是零值

## 动手练习

自定义一个 ClassLoader，把某个 class 文件字节数组 define 进去，独立加载一份与主类同名的类。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《JVM 类加载器详解》《doocs-jvm》《深入理解 JVM 核心技术》《深入理解 Java 虚拟机（第 3 版）》对本节覆盖非常完整，其中《JVM 类加载器详解》开篇就给出了一张「类加载器作用 / 加载路径 / 范围 / 实现」的对照表。

**四类类加载器及各自的加载范围**

《JVM 类加载器详解》给出的实现清单是：

| 类加载器 | 实现语言 | 加载范围 | 典型路径 |
| --- | --- | --- | --- |
| 启动类加载器（Bootstrap ClassLoader） | C++ | JVM 核心类库（java.lang.*、java.util.*） | `JAVA_HOME/jre/lib` 下的核心 jar（rt.jar） |
| 扩展类加载器（Extension ClassLoader） | Java | JVM 扩展类库（javax.*） | `JAVA_HOME/jre/lib/ext` |
| 应用程序类加载器（Application ClassLoader） | Java | 应用程序类路径下的类 | classpath |
| 自定义类加载器 | Java | 由开发者指定 | 自行指定 |

启动类加载器是**唯一不继承 ClassLoader 的**加载器——它由 C++ 实现，是虚拟机自身的一部分。

**类加载的时机与初始化条件**

《doocs-jvm》专门列出「类加载的时机」，而《深入理解 JVM 核心技术》则给出了更精确的「类初始化的条件」：

- 主动使用：new、访问/赋值静态字段、反射调用、初始化子类时先初始化父类、启动类（main 方法所在类）
- **被动使用**（不触发初始化）：通过子类引用父类静态字段、父类 Class 对象、引用常量（编译期常量会被直接内联到调用方，不触发加载）

**双亲委派的破坏**

知识库中《深入理解 Java 虚拟机（第 3 版）》与《深入浅出 Java 多线程》都提到自定义类加载器的存在意义。SPI 是最典型的例子：`ServiceLoader` 从 `META-INF/services` 读实现类名，而 `java.sql.DriverManager` 由 Bootstrap 加载器加载，它无法找到应用层的驱动实现——**这正是主动打破双亲委派的地方**，自定义的线程上下文类加载器（Thread Context ClassLoader）负责加载 SPI 实现。

**类卸载的条件**

《doocs-jvm》指出方法区回收的两个目标是对常量池的回收与**对类型的卸载**。类型卸载需要同时满足三个条件：

1. 该类的所有实例都已被回收（堆中不再存在该类的对象）
2. 加载该类的 ClassLoader 已被回收
3. 该类对应的 Class 对象没有被任何地方引用（`Class.forName`、反射持有的引用都会阻止卸载）

这三条合起来解释了一个生产现象：大量使用动态代理或脚本引擎的应用，元空间只增不减——每次调用都会生成一个新的类，而这些类永远无法卸载。

## 实战提示

排查「类明明写了却找不到」时，按双亲委派链路自下而上检查：

```java
// 打印各类加载器及其加载范围
ClassLoader cl = MyClass.class.getClassLoader();
while (cl != null) {
    System.out.println(cl);   // Application → Platform → null(bootstrap)
    cl = cl.getParent();
}
System.out.println(cl);       // null 表示已到 Bootstrap
```

- `ClassNotFoundException` → 应用类加载器路径没覆盖，检查 jar 包与 classpath
- `NoClassDefFoundError`（初始化后失败）→ 类在但初始化抛过异常，用 `-XX:+ShowClassInitializationExceptions` 看真实原因
- `LinkageError: loader constraint violation` → 同一个类被两个加载器各加载了一份，典型于 SPI 与 Tomcat 的类冲突
