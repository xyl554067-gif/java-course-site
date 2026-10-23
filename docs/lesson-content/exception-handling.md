## 本节要点

Java 异常体系分两大类：**受检异常**（checked，编译器强制捕获）与**非受检异常**（unchecked，RuntimeException 及其子类）。设计原则是「能用受检就用受检，能用非受检就用非受检」——**受检异常用于可预期的、由调用方能处理的错误；非受检用于编程错误**。

## 核心概念

- **Throwable** → Error（严重错误，通常不处理）/ Exception（可预期错误）。
- **受检异常**：Exception 的非 RuntimeException 子类。编译器要求 catch 或 throws。
- **非受检异常**：RuntimeException 及其子类（NullPointerException、IllegalArgumentException、IllegalStateException、ArithmeticException、ClassCastException…）。
- **Error**：StackOverflowError、OutOfMemoryError、NoClassDefFoundError。JVM 层面问题，不该 catch。
- **异常链（cause）**：Throwable 的 `cause` 字段，包装异常时保留原始异常。
- **try-with-resources**（JDK 7+）：自动关闭资源，**且被抑制的异常会被保留**（addSuppressed）。
- **finally 的执行规则**：正常结束、抛异常、return —— 都会执行 finally。**但 System.exit / 致命错误不会**。
- **try-catch 中 return 的坑**：finally 里的 return 会**吞掉** try 块里的 return 或异常。
- **自定义异常**：继承 RuntimeException（不强制捕获）或 Exception（强制捕获）。
- **异常不能用作控制流**：性能开销（构造异常要填栈帧）。
- **全局异常处理器**：Spring 的 @ControllerAdvice、@RestControllerAdvice。

## 关键代码

```java
// try-with-resources：自动关闭，且保留被抑制的异常
try (BufferedReader br = new BufferedReader(new FileReader("f.txt"));
     Writer w = new BufferedWriter(new FileWriter("out.txt"))) {
    String line;
    while ((line = br.readLine()) != null) w.write(line);
}   // 逆序关闭：w 先关，br 后关

// 异常链：保留原始异常
try {
    parse(input);
} catch (NumberFormatException e) {
    throw new BusinessException("解析失败: " + input, e);   // 传 cause
}

// 自定义异常
class BusinessException extends RuntimeException {
    private final String code;
    public BusinessException(String code, String message, Throwable cause) {
        super(message, cause);
        this.code = code;
    }
    public String getCode() { return code; }
}

// 区分「预期的业务异常」与「编程错误」
if (user == null) throw new IllegalArgumentException("user must not be null");
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- catch (Exception e) 一把梭，把所有异常吞掉
- 在 catch 里只 `e.printStackTrace()` 而不处理也不上抛
- 认为 finally 一定会执行——`System.exit()` 时不会
- 忘记自定义异常要调用 `super(message, cause)`，丢失原始堆栈
- catch (Throwable t) ——连 Error 都吞掉，掩盖致命问题

## 动手练习

实现一个健壮的配置解析器：区分格式错误（受检）与缺失字段（非受检），并保证原始异常信息不丢失。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《面试题-03-Java异常面试题》《面渣逆袭 Java 基础篇》《二哥的 Java 进阶之路暗黑版》《Effective+Java+中文第二版》对本节有系统覆盖。

**异常体系与面试高频结论**

《面试题-03-Java异常面试题》开篇即梳理了异常体系：

```
Throwable
├── Error                （严重错误，JVM 层面，不该 catch）
│   ├── OutOfMemoryError
│   ├── StackOverflowError
│   └── NoClassDefFoundError
└── Exception
    ├── RuntimeException （非受检，编译器不强制）
    │   ├── NullPointerException
    │   ├── IllegalArgumentException
    │   ├── IllegalStateException
    │   ├── IndexOutOfBoundsException
    │   └── ArithmeticException
    └── 其他             （受检，编译器强制 catch/throws）
        ├── IOException
        ├── SQLException
        └── ClassNotFoundException
```

**《面渣逆袭 Java 基础篇》给出的选型原则**：

- **受检异常**：异常发生原因可以由调用方处理，且不处理就无法继续 —— 如 IO 失败
- **非受检异常**：程序逻辑错误 —— 如 NPE、数组越界

**try-with-resources 的双重优势**

《Effective Java》第 34 条专门讲这个主题，给出两个理由：

1. **自动关闭资源**，不需要 finally 块
2. **保留被抑制的异常** —— 若 try 块抛异常 A、close() 抛异常 B，A 会被保留，B 作为「被抑制异常」附加到 A 上

```java
// 传统写法：close 抛异常会覆盖原始异常
try (Resource r = open()) {
    r.read();       // 抛异常 A
}                   // close() 抛异常 B → A 被丢失！

// try-with-resources：A 保留，B 成为 suppressed
try (Resource r = open()) {
    r.read();
} catch (Exception e) {
    e.getSuppressed();   // 能拿到 B
}
```

**finally 的执行时机**

《二哥的 Java 进阶之路暗黑版》与《面渣逆袭 Java 基础篇》都强调：

- finally 在方法正常结束、抛异常、return 三种情况下**都会执行**
- **唯一不执行的情况是 JVM 退出**（`System.exit()`）或线程被强制终止
- finally 中的 return 会**吞掉** try 中的 return 或异常——这是经典 bug

```java
// 错误：try 中的 return 被 finally 覆盖
int f() {
    try { return 1; }
    finally { return 2; }   // 永远返回 2
}
```

**异常不能用于控制流**

《Effective Java》第 66 条指出：用异常做正常的控制流是性能反模式。构造异常需要**填充整个调用栈的栈帧**，代价是普通 return 的上百倍。书中建议用返回特殊值或 Optional 表达「预期内的失败」。

**自定义异常的设计**

《二哥的 Java 进阶之路暗黑版》指出自定义异常的三条实践：

1. **总是调用 `super(message, cause)`** ——否则原始异常堆栈丢失
2. **区分受检与非受检**：业务异常通常继承 RuntimeException（避免层层 throws 的样板代码）
3. **不要用异常控制流程**，不要捕获后静默吞掉

**Spring 的全局异常处理**

知识库中《深入浅出Java+23种设计模式》与《面渣逆袭 Spring 篇》覆盖了 Spring 的异常体系。核心注解：

```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusiness(BusinessException e) {
        return ResponseEntity.status(400).body(ApiResponse.fail(e.getCode(), e.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleOther(Exception e) {
        log.error("未预期异常", e);       // 必须记日志
        return ResponseEntity.status(500).body(ApiResponse.fail("INTERNAL_ERROR", "系统繁忙"));
    }
}
```

《面渣逆袭 Spring 篇》强调「统一异常处理的三个好处」：统一返回格式、避免每个 Controller 写 try-catch、集中记录日志。

**《Effective Java》第 47/48 条：不要忽略异常**

- 第 47 条：不要忽略异常——空 catch 块会掩盖问题
- 第 48 条：不要捕获 Throwable 或 Error

## 实战提示

**异常处理的三个层次**：

| 层次 | 做什么 |
| --- | --- |
| 边界层（Controller/消息消费者） | 兜底 + 记日志 + 转成统一响应 |
| 业务层 | 抛业务异常，附带错误码与上下文 |
| 工具层 | 只处理能恢复的异常，其余上抛 |

**判断该不该 catch**：

```
我能在这里修复它吗？      → 不能 → 上抛
调用方能处理它吗？        → 能 → 受检异常 + 文档说明
这是编程错误（bug）？     → 是 → 非受检异常，让它炸出来
```

**性能提示**：热点路径上不要用异常做控制流。`try-catch` 本身几乎无开销（JIT 会优化掉无异常的路径），**真正的开销在于构造异常对象**——它要填充栈帧。

**日志的正确写法**：

```java
// 错误：字符串被无条件拼接，即使不抛异常也有开销
log.debug("处理订单 " + orderId + " 金额 " + amount);

// 正确：参数化日志，异常时才格式化
log.debug("处理订单 {} 金额 {}", orderId, amount);

// 错误：丢失堆栈
log.error("出错了: " + e.getMessage());

// 正确：传 Throwable 本身
log.error("处理订单失败", e);
```
