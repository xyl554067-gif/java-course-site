## 本节要点

反射让程序在**运行时**检查和操作类型：读注解、创建实例、调用方法、访问字段。注解是给**编译器/JVM**看的元数据，`@Retention` 决定它的生命周期，运行时注解配合反射才能被读取。

## 核心概念

- **Class 对象**：每个类在 JVM 中都有唯一的 Class 实例，持有该类的全部元信息。
- **反射 API**：`Class`、`Method`、`Field`、`Constructor`、`Modifier`。
- **注解的 Retention**：`SOURCE`（仅源码，编译丢弃）/ `CLASS`（编译进 class 文件，运行时不可读）/ `RUNTIME`（运行时可读，最常用）。
- **注解的 Target**：`TYPE`、`METHOD`、`FIELD`、`PARAMETER` 等，限定可标注位置。
- **@Inherited**：允许子类继承父类的注解（只对类有效）。
- **重复注解**：`@Repeatable`（Java 8+）。
- **元注解**：标注注解的注解（`@Retention`、`@Target`、`@Documented`、`@Inherited`）。
- **动态代理**：`Proxy.newProxyInstance` 基于接口生成代理类，Spring AOP 的底层。
- **性能代价**：反射比直接调用慢（需装箱、访问检查），但 JIT 会对热点反射做优化。
- **setAccessible(true)**：突破访问控制，JDK 9+ 对 JDK 内部模块有强限制。
- **MethodHandle**（Java 7+）：比反射更快，是 JDK 内部（如 lambda）的实现基础。

## 关键代码

```java
// 定义运行时注解
@Retention(RetentionPolicy.RUNTIME)     // 运行时可读
@Target({ElementType.METHOD, ElementType.TYPE})
@interface MyAnnotation {
    String value() default "";
    int priority() default 0;
}

// 读取注解
Method method = MyService.class.getMethod("doWork");
if (method.isAnnotationPresent(MyAnnotation.class)) {
    MyAnnotation ann = method.getAnnotation(MyAnnotation.class);
    System.out.println(ann.value() + " / " + ann.priority());
}

// 反射创建实例与调用方法
Class<?> clazz = Class.forName("com.example.Foo");
Object obj = clazz.getDeclaredConstructor().newInstance();
Method m = clazz.getMethod("hello", String.class);
Object result = m.invoke(obj, "world");

// 访问私有字段
Field field = Foo.class.getDeclaredField("secret");
field.setAccessible(true);
System.out.println(field.get(obj));

// 动态代理（Spring AOP 基础）
interface Service { String doWork(String arg); }
Service proxy = (Service) Proxy.newProxyInstance(
        Service.class.getClassLoader(),
        new Class<?>[]{Service.class},
        (p, method, args) -> "代理前拦截 -> " + method.invoke(p, args));
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 忘了 `@Retention(RetentionPolicy.RUNTIME)`，注解编译后就没了，运行时读不到
- 认为 `@Inherited` 对方法注解有效——只对类注解有效
- 在反射调用时忘了处理 `InvocationTargetException`——真实异常被包装了
- 滥用 `setAccessible(true)` 突破封装，JDK 9+ 模块系统下会失败
- 用反射做本可以静态调用的热路径，性能损失明显

## 动手练习

实现一个极简的「注解 + 反射」依赖注入：自定义 `@Inject` 注解，扫描字段并自动赋值。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《SpringIOC核心技术-冰河》《Spring源码深度解析（第 2 版）》《深入浅出Java+23种设计模式》《二哥的 Java 进阶之路暗黑版》对本节机制有原理性支撑。

**注解的 Retention 与生命周期**

《二哥的 Java 进阶之路暗黑版》指出注解的三种保留策略决定了它能活多久：

| Retention | 生命周期 | 典型用途 |
| --- | --- | --- |
| `SOURCE` | 只在源码，编译即丢弃 |  Lombok、Checkstyle 注解 |
| `CLASS` | 进 class 文件，运行时不可读（默认） | 字节码增强工具 |
| `RUNTIME` | 保留到运行，**反射可读** | Spring 的 `@Component`/`@Transactional`、JUnit 的 `@Test` |

**默认是 `CLASS`**——这是最常见的踩坑点：写了注解却读不到，多半是忘了显式声明 `RUNTIME`。

**Spring 的注解驱动本质**

《SpringIOC核心技术-冰河》系统讲解了 Spring 的 IOC 实现原理，核心链路正是「注解 + 反射」：

```
@Component 扫描 → 解析出 bean 定义 → 实例化（反射调用构造器）
    → 依赖注入（反射设置字段 / 调用 setter）
    → AOP 代理（动态代理 / 字节码增强）
```

知识库中《Spring 源码深度解析（第 2 版）》与《SpringIOC核心技术》都指出：Spring 的注解本身只是**元数据**，真正干活的是 `AnnotationBeanNameGenerator`、`AutowiredAnnotationBeanPostProcessor` 这些后置处理器——它们通过反射读取注解并执行相应操作。

这正是理解反射价值的最佳案例：**注解本身什么都不做，是反射让它产生效果**。

**动态代理 JDK 与 CGLIB**

《深入浅出Java+23种设计模式》与《SpringIOC核心技术》都对比了两种 AOP 实现：

| | JDK 动态代理 | CGLIB（字节码增强） |
| --- | --- | --- |
| 前提 | 必须有**接口** | 无需接口（生成子类） |
| 实现 | `Proxy.newProxyInstance` | ASM / ByteBuddy 生成字节码 |
| 局限 | 只能代理接口方法 | 不能代理 final 类/方法 |

Spring Boot 2.x 之后默认用 CGLIB，因为 Spring 6 / Boot 3 起不再强制要求实现接口。

**代理模式在《深入浅出Java+23种设计模式》中的位置**

这本书把代理模式分为三类：

1. **静态代理**：编译期确定代理类，代码冗余
2. **JDK 动态代理**：运行期基于接口生成 `Proxy` 子类
3. **CGLIB 动态代理**：运行期基于类生成子类

《SpringIOC核心技术-冰河》特别指出 JDK 动态代理的调用链：

```java
// Proxy 内部持有 InvocationHandler
Object result = method.invoke(this, args);   // 转调 handler.invoke()
// handler 里再反射调用真实对象的方法
```

**MethodHandle 与反射的对比**

《二哥的 Java 进阶之路暗黑版》提到 JDK 7 引入的 `MethodHandle`：

- 反射：Method 对象在运行时**查找**得到，有访问检查
- MethodHandle：可以**提前绑定**（`bindTo`），执行时无查找开销

JDK 内部的 lambda 实现就基于 `LambdaMetafactory` + `MethodHandle`，这解释了为什么 lambda 比匿名内部类更省资源。

**反射的性能真相**

《二哥的 Java 进阶之路暗黑版》与《深入浅出Java+23种设计模式》都指出：现代 JVM 对反射做了大量优化（JDK 18+ 的 `MethodHandle` 反射、JDK 21+ 的 hidden classes），热点反射调用的性能差距已大幅缩小。但仍有开销：

- 参数装箱/拆箱
- 每次调用的访问权限检查
- 无法被 JIT 完全内联

结论：**非热点路径用反射无妨，热路径（如每次请求都调）应缓存 `Method` 对象或改用接口/lambda**。

**setAccessible 的限制**

《二哥的 Java 进阶之路暗黑版》指出 JDK 9+ 引入模块系统后：

- `setAccessible(true)` 对**本模块**与**开放模块**有效
- 对 JDK 内部类（如 `java.lang`）会抛 `InaccessibleObjectException`
- 需要 `--add-opens java.base/java.lang=ALL-UNNAMED` 才能访问

这也是 Spring 在 JDK 17+ 需要 `--add-opens` 参数的原因之一。

## 实战提示

**自定义注解的完整模板**：

```java
// 定义
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.FIELD)
@Documented
public @interface Inject {
    boolean required() default true;
}

// 处理
class Injector {
    static void inject(Object target) throws Exception {
        for (Field field : target.getClass().getDeclaredFields()) {
            if (field.isAnnotationPresent(Inject.class)) {
                field.setAccessible(true);
                field.set(target, createBean(field.getType()));
            }
        }
    }
}
```

**读不到注解时的排查顺序**：

1. `@Retention` 是 `RUNTIME` 吗？（最常见）
2. `@Target` 包含目标位置吗？（比如只标了 METHOD 却标在字段上）
3. 注解在**运行时**被保留了吗？（打包插件可能过滤）
4. 是不是代理类导致 `getAnnotation` 拿不到？（用 `AopUtils.getTargetClass` 或 `AnnotationUtils`）

**反射的正确异常处理**：

```java
try {
    method.invoke(obj, args);
} catch (InvocationTargetException e) {
    // 真实异常在 getCause() 里
    throw new BusinessException("调用失败", e.getCause());
} catch (IllegalAccessException e) {
    throw new IllegalStateException("访问权限不足", e);
}
```

**缓存反射结果**：

```java
// 反射结果应当缓存，不要每次都查
private static final Map<Method, MethodHandle> HANDLE_CACHE = new ConcurrentHashMap<>();

// 或者更简单：把反射得到的对象缓存到字段
private final Method cachedMethod = ...;
```

**什么时候该用反射 / 什么时候不该**：

| 场景 | 选择 |
| --- | --- |
| 框架解耦（Spring、MyBatis、JUnit） | 反射 |
| 读取运行时配置/注解 | 反射 |
| 需要动态替换实现 | 动态代理 |
| 业务代码里频繁调用的方法 | 直接调用或用接口 + lambda |
| 编译期就能确定的东西 | 不用反射 |
