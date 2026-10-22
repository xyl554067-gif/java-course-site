#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
为42 个课时补上结构化的Markdown 正文。

背景: 初始 seed.sql 里的 content 只是单段摘要（40~100 字符），
      前端 Markdown 渲染器没有标题/列表/代码块可渲染，页面显得空洞。
      本脚本按每个课时的知识点生成「学习目标 / 核心概念 / 关键代码 /
      常见误区 / 动手练习」五段式正文，并同步刷新 search_index.body_text
      以保证搜索能命中新正文。

用法: python scripts/enrich_content.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
JDBC_JAR = os.path.join(ROOT, "backend", "lib", "kingbase8-8.6.0.jar")

DB = {
    "host": "127.0.0.1",
    "port": "54321",
    "db": "javacourse",
    "user": "javacourse_app",
    "pw": "App@Course2026",
}

# slug -> (核心概念要点, 关键代码, 常见误区, 练习题)
# 每课一条，内容按该课主题定制，不是模板填空。
CONTENT = {
"hello-world": (
    ["JDK、JRE、JVM 三者的包含关系", "源码到运行：javac 编译与 java 执行", "为什么 Java 能跨平台"],
    '''public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}''',
    ["以为 JDK、JRE、JVM 是三选一，实际上是层层包含", "编译和运行用的是不同命令：javac 编译，java 运行"],
    "新建一个目录，用记事本写 HelloWorld.java，用 javac 编译后用 java 运行，亲眼看到 .class 文件是怎么生成的。"),

"variables-and-types": (
    ["8 种基本类型的字节数与取值范围", "char 为什么是 16 位而不是 8 位", "基本类型与包装类型的转换"],
    '''int i = 21;          // 4 字节，范围约 ±21 亿
long l = 21L;         // 8 字节，必须加 L 后缀
double d = 21.0;      // 8 字节
char c = 'A';         // 2 字节，UTF-16 编码
boolean b = true;     // 1 位（实际分配 1 字节）

// 超过 int 范围必须显式写 long
long big = 3000000000L;''',
    ["认为 long 可以省略 L，导致字面量默认按 int 解析直接编译失败", "认为 char 是 ASCII 的 8 位字符，忽略了 Unicode 支持"],
    "画一张内存图，标注每种基本类型占用的字节数，并算出各自的取值范围。"),

"operators": (
    ["i++ 与 ++i 的返回值与副作用时机", "浮点数精度丢失的根本原因", "短路求值 & | 的执行顺序"],
    '''int i = 1;
System.out.println(i++);  // 打印 1，i 变成 2（后置：先用后加）
System.out.println(++i);  // 打印 3，i 变成 3（前置：先加后用）

// 浮点陷阱
System.out.println(0.1 + 0.2);       // 0.30000000000000004
System.out.println(0.1 + 0.2 == 0.3);// false

// 短路求值
boolean r = (i != 0) && (10 / i > 1);  // i==0 时右边根本不执行''',
    ["在表达式里同时读写同一个变量，如 `sum = sum + i++`，导致难以调试", "用 == 比较 double 做相等判断"],
    "用 javap -c 反编译一段含 i++ 的代码，对比前置与后置的字节码差异。"),

"control-flow": (
    ["增强版 switch 的箭头语法（Java 14+）", "break 与 continue 的真实作用域", "for-each 的底层迭代器机制"],
    '''switch (day) {
    case MONDAY, FRIDAY -> System.out.println("工作日");
    case SUNDAY -> System.out.println("休息日");
    default -> System.out.println("其他");
}

for (String item : list) {
    if (item.isEmpty()) continue;   // 跳过空串，继续下一次迭代
    if (item.equals("stop")) break;  // 直接跳出整个循环
    System.out.println(item);
}''',
    ["以为 continue 会跳过整个循环，实际上只跳过本次迭代", "老式 switch 忘记写 break 导致贯穿执行"],
    "用增强版 switch 重写一段判断月份天数的代码，对比新旧写法行数。"),

"arrays": (
    ["数组是引用类型，赋值即共享", "越界异常的产生时机", "Arrays.stream 的并行流优势"],
    '''int[] a = new int[5];         // 默认全0
int[] b = {1, 2, 3, 4, 5};

int[] c = b;                   // c 与 b 指向同一个数组！
c[0] = 100;
System.out.println(b[0]);      // 100，数组是引用传递

// 越界
try {
    System.out.println(b[5]);   // ArrayIndexOutOfBoundsException
} catch (ArrayIndexOutOfBoundsException e) {
    System.out.println("下标越界");
}

// 优雅遍历
Arrays.stream(b).filter(x -> x % 2 == 0).forEach(System.out::println);''',
    ["以为 int[] c = b 是复制了一份数组，实际上两个变量指向同一块内存", "遍历大数组时用普通 for 循环而非并行流，浪费多核"],
    "写一个方法接收 int[] 参数并尝试修改元素，回到主方法打印原数组，验证引用共享。"),

"project-guess-number": (
    ["用Random.nextInt 生成随机数的正确姿势", "循环终止条件与次数控制", "难度分级如何用参数表达"],
    '''import java.util.Random;
import java.util.Scanner;

public class GuessNumber {
    public static void main(String[] args) {
        Random rnd = new Random();
        int target = rnd.nextInt(100) + 1;   // 注意是左闭右开
        Scanner sc = new Scanner(System.in);

        for (int i = 1; i <= 7; i++) {
            System.out.print("第 " + i + " 次猜测：");
            int guess = sc.nextInt();
            if (guess == target) {
                System.out.println("猜对了！一共用了 " + i + " 次");
                return;
            }
            System.out.println(guess < target ? "太小了" : "太大了");
        }
        System.out.println("次数用完了，正确答案是 " + target);
    }
}''',
    ["用 nextInt(100) 却期望能取到 100，忘记右端点不包含", "把 Scanner 写完不关闭，在部分环境下会阻塞"],
    "给游戏加三个难度：简单 1~50 七次、中等 1~100 十次、困难 1~500 五次。"),

"string": (
    ["String 的不可变性设计", "字符串常量池与 intern()", "StringBuilder 与 StringBuffer 的取舍"],
    '''String a = "hello";
String b = "hello";
System.out.println(a == b);      // true，都指向常量池同一对象

// 循环拼接：O(n²)，字符串常量池里产生大量垃圾
String s = "";
for (int i = 0; i < 1000; i++) s += i;    // 慢

// 正确做法：O(n)
StringBuilder sb = new StringBuilder();
for (int i = 0; i < 1000; i++) sb.append(i);
String result = sb.toString();''',
    ["用 + 号在循环里拼接字符串，把 O(n) 变成 O(n²)", "误以为 s += \"x\" 会修改原字符串，实际是生成了新对象"],
    "分别用 + 号和 StringBuilder拼接 10000 次字符串，用 System.currentTimeMillis 计时对比。"),

"methods": (
    ["Java 只有值传递，没有引用传递", "对象参数传的是引用的副本", "基本类型与对象参数的差异"],
    '''static void changeInt(int n) { n = 100; }
static void changeObj(int[] arr) { arr[0] = 100; }

public static void main(String[] args) {
    int a = 1;
    changeInt(a);
    System.out.println(a);              // 1，值传递改的是副本

    int[] arr = {1, 2, 3};
    changeObj(arr);
    System.out.println(arr[0]);         // 100，能改到是因为副本指向同一数组
}''',
    ["宣称 Java 支持引用传递，或者靠 swap 方法交换两个变量却没生效", "把对象参数改成 null，以为调用方也会变成 null"],
    "写一个 swap(int[] arr, int i, int j) 方法，在主方法里交换数组两元素并验证。"),

"class-and-object": (
    ["实例字段与静态字段的生命周期差异", "构造器链与super 调用", "this 的两种用法"],
    '''public class Student {
    private String name;          // 实例字段：每个对象一份
    private static int count = 0;// 静态字段：整个类一份

    private final int id;

    public Student(String name) {
        this.name = name;         // this.字段，区分同名参数
        this.id = ++count;        // 构造器链中分配唯一编号
        System.out.println("创建了第 " + count + " 个学生");
    }

    public String getName() { return this.name; }
}''',
    ["在静态方法里直接访问实例字段，报 static 上下文中无法引用非静态变量", "构造器里调用可重写方法，子类还没初始化完就被调用"],
    "写一个计数器类，每 new 一次就自动分配递增的序号，验证静态字段被所有实例共享。"),

"oop-core": (
    ["重写(Override)与重载(Overload) 的本质区别", "运行时多态的绑定时机", "继承的实现与代价"],
    '''// 重载：编译期决定，同名不同参数
void show(int n)    { System.out.println("int"); }
void show(String s) { System.out.println("String"); }

// 重写：运行期决定，子类覆盖父类行为
class Animal { void speak() { System.out.println("动物叫"); } }
class Dog extends Animal {
    @Override void speak() { System.out.println("汪汪"); }  // 注解让编译器检查
}

Animal a = new Dog();
a.speak();   // 汪汪 —— 运行时多态，看的是实际类型''',
    ["把重载当成重写，或者反过来", "在子类构造器中调用可重写方法，导致子类字段尚未初始化"],
    "用一段 Animal/Dog/Cat 的多态代码，打印每种动物实际执行的方法，验证绑定时机。"),

"interface-vs-abstract": (
    ["接口与抽象类的本质区别", "Java 8 默认方法化解多继承困境", "面向接口编程的可操作准则"],
    '''interface Flyable {
    void fly();
    default void land() {          // 默认方法，子类可不重写
        System.out.println("默认降落");
    }
}

abstract class Bird {
    abstract void eat();
    void sleep() { System.out.println("鸟睡觉"); }
}

// 准则：能用接口就用接口，需要共享实现代码才考虑抽象类''',
    ["滥用抽象类，导致子类被迫继承不该继承的行为", "认为接口只能有抽象方法，忽略了 default 与 static 方法"],
    "定义一个 Drawable 接口，让 Circle 和 Square 分别实现，再让它们共享一个默认的面积检查方法。"),

"final-static-immutable": (
    ["不可变对象三板斧", "final 字段与JMM 可见性保证", "防御性拷贝的必要性"],
    '''public final class Point {
    private final int x;    // 1. 字段全final
    private final int y;

    public Point(int x, int y) { this.x = x; this.y = y; }

    public Point translate(int dx, int dy) {  // 2. 返回新对象，不改自己
        return new Point(x + dx, y + dy);
    }

    public int[] getArray() {
        return arr.clone();  // 3. 防御性拷贝，不泄漏内部引用
    }
}''',
    ["字段声明为 final 却仍在构造器外被赋值", "可变数组直接从 getter 返回，外部能改到内部状态"],
    "把一个可变对象改造成不可变对象，让所有修改方法返回新实例，验证外部无法影响其状态。"),

"enum-and-record": (
    ["枚举的隐式 final 与单例保证", "枚举也能有抽象方法和构造器", "record 的自动生成机制"],
    '''public enum Planet {
    MERCURY(3.3e23, 2.44e6),
    EARTH(5.97e24, 6.37e6);

    private final double mass;
    private final double radius;

    Planet(double mass, double radius) {   // 枚举可以有构造器
        this.mass = mass;
        this.radius = radius;
    }

    public double surfaceGravity() { return 6.67e-11 * mass / (radius * radius); }
}

// record 一行定义不可变数据载体，编译器自动生成构造器、equals、hashCode、toString
public record Point2(int x, int y) {}''',
    ["认为枚举只能装常量，忽略了它可以有字段和方法", "还在手写 30 行构造器的数据类，record 一行就够"],
    "用枚举实现一个带自定义字段和方法的支付方式，再对比 record 与传统类的样板代码量。"),

"inner-class-and-lambda": (
    ["四种内部类的访问权限差异", "匿名内部类的快速写法", "Lambda 与函数式接口"],
    '''class Outer {
    private int count = 0;

    class Inner {                      // 成员内部类，可访问外部字段
        void add() { count++; }
    }

    static class StaticInner {}        // 静态内部类，不依赖外部实例

    void run() {
        Runnable r = () -> System.out.println("Lambda 表达式");  // Lambda
        new Thread(new Runnable() {   // 匿名内部类
            @Override public void run() { System.out.println("匿名"); }
        }).start();
    }
}''',
    ["在静态方法里创建非静态内部类对象，失去外部类实例", "Lambda 捕获的局部变量必须是 final 或事实上不可变"],
    "用 Lambda 写一个 Comparator，对一组字符串按长度再按字典序排序，对比匿名内部类写法。"),

"exception-handling": (
    ["受检与非受检异常的分界", "try-with-resources 的自动关闭", "finally 的执行时机与陷阱"],
    '''// 推荐：try-with-resources 编译后等价于 try-catch-finally，且会抑制异常
try (BufferedReader br = new BufferedReader(new FileReader("data.txt"))) {
    String line;
    while ((line = br.readLine()) != null) {
        System.out.println(line);
    }
} catch (IOException e) {        // 受检异常必须处理
    throw new BusinessException("读取失败", e);
}

// 反模式：手动关闭时容易漏
Connection conn = null;
try {
    conn = DriverManager.getConnection(url);
} finally {
    if (conn != null) conn.close();  // 这里再抛异常会覆盖原异常
}''',
    ["用 catch (Exception e) {} 把所有异常吞掉，故障静默", "用 e.printStackTrace() 而非向上传递或记录日志"],
    "把一段手动 close 的 JDBC 代码改写成 try-with-resources，对比代码行数与异常安全性。"),

"generics-type-erasure": (
    ["类型擦除的实现原理", "为什么 List<int> 不合法", "桥接方法与多态的配合"],
    '''// 泛型不能用于基本类型
List<Integer> a = new ArrayList<>();   // 合法
// List<int> b = new ArrayList<>();     // 编译错误，必须装箱

// 编译器把 T 擦除成 Object，必要时插入强制转换并生成桥接方法
public class Node<T> {
    T value;
    public void set(T v) { this.value = v; }
}
// 编译后等价于：set(Object v)，并在调用处强转''',
    ["试图写 List<int>，忽略了基本类型不能作为类型参数", "以为泛型信息在运行时保留，可以反射出 T 的实际类型"],
    "写一个泛型方法 <T extends Comparable<T>> T max(List<T> list)，编译后用 javap 查看擦除后的签名。"),

"reflection-annotation": (
    ["Class、Field、Method 三大反射入口", "注解的 Retention 与 Target", "反射的性能代价"],
    '''// 定义注解：运行时可见
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
@interface MyTest {
    String value() default "未命名";
}

// 读取注解
Method m = MyClass.class.getMethod("doSomething");
MyTest ann = m.getAnnotation(MyTest.class);
if (ann != null) System.out.println(ann.value());''',
    ["默认 Retention 是 CLASS，运行时读不到，必须显式指定 RUNTIME", "反射后忘记 setAccessible(true)，访问私有成员失败"],
    "定义一个自定义注解，写一个工具方法扫描类中所有带该注解的方法并逐个调用。"),

"project-grade-system": (
    ["需求到类设计的推导过程", "面向接口编程的收益", "异常处理在业务层的落点"],
    '''// 面向接口：换存储实现不影响业务层
interface StudentDao {
    void save(Student s);
    Student findById(long id);
}

class MemoryStudentDao implements StudentDao { /* 内存实现 */ }
// 业务层只依赖接口，将来换成 MySQL 实现无需改业务代码
class GradeService {
    private final StudentDao dao;
    GradeService(StudentDao dao) { this.dao = dao; }
}''',
    ["把 StudentDao 实现类写死，替换数据库时改动面扩散到整个系统", "业务层直接写 SQL，让 DAO 层形同虚设"],
    "先用内存版 StudentDao 实现成绩管理，再实现一个基于 Map 的版本，两者可互换使用。"),

# ---------------- 模块 3：集合框架 ----------------
"collection-overview": (
    ["List / Set / Map 三大分支的定位", "为什么要有 Iterable 而不直接返回集合", "选型决策表"],
    '''List<String> list = new ArrayList<>();   // 有序、可重复、可按索引访问
Set<String> set = new HashSet<>();        // 不可重复、查询快
Map<K, V> map = new HashMap<>();          // 键值对，key 不可重复

// 选型口诀：看是否需要重复、是否需要按键查找、是否需要顺序''',
    ["查完接口就随意选实现类，不看访问模式", "认为 Set 一定比 List 快，忽略数据规模与哈希质量"],
    "把一组字符串分别存入 List、Set、Map，统计去重前后数量与查找耗时。"),

"arraylist-source": (
    ["动态数组与扩容机制", "size() 为 O(1) 的原因", "Arrays.copyOf 的作用"],
    '''// 源码核心逻辑（简化）
public boolean add(E e) {
    ensureCapacity();              // 容量不够就扩容
    elementData[size++] = e;      // 尾部写入，O(1) 均摊
    return true;
}

private void ensureCapacity() {
    if (size == elementData.length)
        elementData = Arrays.copyOf(elementData, size * 2);  // 1.5 倍或 2 倍
}

// size() 只是返回字段，O(1)
public int size() { return size; }''',
    ["认为 ArrayList 插入一定是 O(1)，忽略偶尔扩容时的 O(n)", "已知容量却用 Arrays.asList 创建不可变列表，add 直接抛异常"],
    "预置容量 10 依次 add 30 个元素，用调试器观察 elementData.length 的变化次数。"),

"hashmap-red-black-tree": (
    ["哈希桶与链表结构", "树化阈值 8 与退化阈值 6", "扰动函数的作用"],
    '''// 核心参数
static final int DEFAULT_CAPACITY = 16;
static final float LOAD_FACTOR = 0.75f;
static final int TREEIFY_THRESHOLD = 8;   // 链表长度 ≥8 转红黑树
static final int UNTREEIFY_THRESHOLD = 6; // 树缩回链表的阈值

// 为什么阈值是 8：泊松分布下冲突到 8 的概率极低，
// 正常情况链表很短，转树主要是为了对抗恶意构造的哈希碰撞''',
    ["认为 HashMap 是绝对线程安全的，并发下会成环导致 CPU 100%", "只记「冲突转红黑树」却不知道为什么阈值是 8"],
    "构造一组key，让 hashCode 只差 1，插入 10 个观察链表是否树化（需包级访问或反射）。"),

"concurrenthashmap": (
    ["JDK7 分段锁与 JDK8 CAS + synchronized", "size() 如何无锁统计", "与 Hashtable 的本质差别"],
    '''// JDK8 核心：CAS 插入空桶，桶内有元素则 synchronized 锁桶头
if ((tab = table) == null || (n = tab.length) == 0)
    tab = initTable();
else if ((f = tabAt(tab, i = (n - 1) & h)) == null)
    // CAS 成功即插入完成，无需加锁
    if (casTabAt(tab, i, null, newNode(hash, key, val, null)))
        break;
else
    synchronized (f) { /* 锁住桶头节点 */ }''',
    ["以为分段锁思想还在 JDK8，实际已被 CAS + 桶级锁取代", "并发扩容时用 size() 判断业务状态，size 只是估算值"],
    "用 16 个线程各写 1 万个 key 到 ConcurrentHashMap，验证无数据丢失。"),

"set-family": (
    ["HashSet / LinkedHashSet / TreeSet 的差异", "TreeSet 的排序与去重依据", "选择依据"],
    '''Set<String> hs = new HashSet<>();          // 无序，hash 去重
Set<String> ls = new LinkedHashSet<>(hs);   // 保持插入顺序
Set<String> ts = new TreeSet<>(Comparator.reverseOrder()); // 按规则排序

// TreeSet 要求元素可比：实现 Comparable 或传 Comparator''',
    ["用 TreeSet 却不指定比较器，插入不可比元素抛 ClassCastException", "误以为 HashSet 能存两个相等的对象，它靠 hashCode + equals 去重"],
    "把同一个字符串列表分别存入三种 Set，打印迭代顺序，观察差异。"),

"iterator-cmc": (
    ["Iterator 接口与 fail-fast 机制", "ConcurrentModificationException 的成因", "CopyOnWriteArrayList 的取舍"],
    '''List<String> list = new ArrayList<>(List.of("a", "b", "c"));
Iterator<String> it = list.iterator();
while (it.hasNext()) {
    String s = it.next();
    if (s.equals("b")) list.remove(s);   // 直接改集合 → fail-fast
}
// 正确做法：用迭代器自身的 remove()
it = list.iterator();
while (it.hasNext()) {
    if (it.next().equals("b")) it.remove();
}''',
    ["遍历时用集合自身的 remove/delete 导致 CME，其实应用迭代器的 remove", "给 CopyOnWriteArrayList 频繁写入，数组全量复制导致性能极差"],
    "复现一次 ConcurrentModificationException，再用迭代器 remove 修正，对比结果。"),

"stream-api": (
    ["惰性求值与终端操作", "Collectors 分组聚合", "并行流的适用条件"],
    '''List<Order> orders = getOrders();

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
       .forEach(System.out::println);''',
    ["在 Stream 里做副作用操作（println、修改外部变量），破坏可读性", "对数据量小的集合用并行流，线程调度开销反而更慢"],
    "把一个订单列表按用户分组，输出每个用户的订单数与总金额。"),

"project-stream-refactor": (
    ["从命令式到声明式的重构思路", "何时该停止抽象", "可读性与性能的平衡"],
    '''// 命令式：三层嵌套过滤
List<String> result = new ArrayList<>();
for (Order o : orders) {
    if (o.getStatus() == PAID) {
        if (o.getAmount() > 100) {
            result.add(o.getUserName());
        }
    }
}

// 声明式：一次表达意图
List<String> result2 = orders.stream()
    .filter(o -> o.getStatus() == PAID)
    .filter(o -> o.getAmount() > 100)
    .map(Order::getUserName)
    .toList();''',
    ["把简单循环硬改成 Stream，可读性反而下降", "链路过长（一行塞 10 个操作），难以调试"],
    "把手写的一道统计题用 Stream 重写，再对照两版代码的行数与可读性。"),

# ---------------- 模块 4：JVM ----------------
"jvm-memory": (
    ["线程私有区与线程共享区", "堆与栈的分配差异", "内存溢出的两种典型形态"],
    '''// 堆：所有线程共享，存放对象实例，GC 主战场
Student s = new Student();     // 对象在堆上

// 栈：线程私有，存放局部变量表与操作数栈
void foo() {
    int a = 10;// a 的值在当前线程栈的局部变量表
    String b = "hi";     // b 的引用在栈，字符串对象在堆
}

// 典型溢出
List<byte[]> leak = new ArrayList<>();  // 堆溢出：OutOfMemoryError: Java heap space
void recurse() { recurse(); }          // 栈溢出：StackOverflowError''',
    ["以为基本类型也在堆上，其实局部基本类型在栈", "分不清 StackOverflowError 与 OutOfMemoryError 的成因"],
    "写一个递归方法让它栈溢出，再写一个死循环往List 里加对象让它堆溢出，观察报错差异。"),

"object-layout": (
    ["对象头、实例数据与对齐填充", "压缩指针与内存占用", "字段重排优化"],
    '''// 一个空对象在 64 位 JVM 上占 16 字节：12 字节对象头 + 4 字节对齐
Object o = new Object();          // 16 bytes

// 加一个 int 字段后仍是 16 字节（补齐对齐）
class A { int i; }                 // 12 + 4 = 16

// 加两个 int 后变24（8 字节对齐）
class B { int i; int j; }          // 12 + 8 = 20 -> 对齐到 24

// 压缩指针（默认开启）：4 字节表示引用，堆 ≤32G 时生效
-XX:+UseCompressedOops''',
    ["只记「对象有对象头」却不知道 64 位下是 12 字节", "以为引用一定是 8 字节，忽略了压缩指针"],
    "用 JOL（Java Object Layout）工具打印多个类的实例大小，观察字段排列与补齐。"),

# ---------------- 模块 5：并发 ----------------
"thread-basics": (
    ["六种线程状态与转换", "中断机制为何优于 stop", "守护线程的语义"],
    '''Thread t = new Thread(() -> {
    while (!Thread.currentThread().isInterrupted()) {
        try {
            Thread.sleep(100);       // 阻塞中被 interrupt 会抛 InterruptedException
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();  // 恢复标志位，别吞掉
            break;
        }
    }
});
t.start();
t.interrupt();// 请求中断，而非粗暴终止''',
    ["还在用 Thread.stop() 强杀线程，会破坏锁状态导致数据不一致", "catch InterruptedException 后不恢复中断标志，上层感知不到"],
    "写一个可被中断的轮询线程，主线程在 5 次循环后调用 interrupt，观察状态变化。"),

"lock-mechanism": (
    ["synchronized 的锁升级过程", "ReentrantLock 的独占与共享", "公平锁与非公平锁"],
    '''// synchronized 锁升级：偏向 → 轻量级（CAS 自旋）→ 重量级（OS 互斥）
synchronized (lockObj) {
    // 临界区
}

// ReentrantLock 提供更丰富的能力
ReentrantLock lock = new ReentrantLock(true);   // true = 公平锁
lock.lock();
try {
    // 业务代码
} finally {
    lock.unlock();      // 必须在 finally 里释放
}
lock.lockInterruptibly();// 可中断的加锁''',
    ["lock() 后忘记 unlock()，通常要写在 finally 里", "认为公平锁性能更好，实际吞吐量明显低于非公平锁"],
    "用两个线程给同一个 int 加 100 万次，用 synchronized 与 ReentrantLock 各跑一次看结果。"),

"atomic-classes": (
    ["CAS 机制与 ABA 问题", "AtomicInteger 的核心方法", "LongAdder 的分段累加"],
    '''AtomicInteger count = new AtomicInteger(0);

// CAS 自旋：比较并交换，失败则重试
count.incrementAndGet();            // 原子 +1
count.compareAndSet(5, 10);         // 值等于 5 才改成 10，返回是否成功
count.getAndIncrement();            // 返回旧值

// LongAdder：高并发下用分段累加降低 CAS 冲突
LongAdder adder = new LongAdder();
adder.increment();
long sum = adder.sum();             // 注意 sum() 不是原子快照''',
    ["自己用 synchronized 包住所有自增，牺牲性能换正确性", "用 AtomicInteger 做所有累加，高并发下成为瓶颈，此时该上 LongAdder"],
    "16 个线程各累加 100 万次，分别用 int+ synchronized、AtomicInteger、LongAdder 计时对比。"),

"completablefuture": (
    ["supplyAsync 与 runAsync 的区别", "thenApply 与 thenCompose 的语义", "异常处理与超时"],
    '''CompletableFuture<String> future =
    CompletableFuture.supplyAsync(() -> fetchUser(id))     // 有返回值
        .thenApply(user -> user.getName())                  // 转换结果
        .thenCompose(name -> fetchProfile(name))            // 串接另一个异步任务
        .exceptionally(ex -> "默认值")
        .orTimeout(3, TimeUnit.SECONDS);

// 多个任务并行执行再汇总
CompletableFuture.allOf(taskA, taskB, taskC)
        .thenApply(v -> merge());''',
    ["用 thenApply 处理返回异步任务的结果，实际应�� thenCompose", "在异步链里吞掉异常，导致下游一直等不到结果"],
    "并行请求三个接口再汇总结果，整体加上 3 秒超时与异常兜底。"),

"lock-free-queue": (
    ["CAS 队列与阻塞队列的取舍", "ConcurrentLinkedQueue 的无锁实现", "队列选型场景"],
    '''// 无锁队列：CAS + CAS，全程不阻塞
ConcurrentLinkedQueue<String> lockFree = new ConcurrentLinkedQueue<>();
lockFree.offer("task");              // 入队，无锁
String head = lockFree.peek();

// 阻塞队列：可指定容量，满时阻塞或抛异常
BlockingQueue<String> blocking = new ArrayBlockingQueue<>(10);
blocking.put("task");                // 满了等待
blocking.offer("task", 1, TimeUnit.SECONDS); // 带超时的入队''',
    ["在生产者消费者场景用无锁队列，堆积时可能吃满内存", "误以为 ConcurrentLinkedQueue 的 size() 是精确值，它只是估算"],
    "用ArrayBlockingQueue 实现一个容量为 5 的生产者消费者，并演示队列满时的阻塞。"),

"threadpool": (
    ["七个参数的工程含义", "CPU 密集 vs IO 密集的差异化配置", "拒绝策略的选择"],
    '''ThreadPoolExecutor pool = new ThreadPoolExecutor(
    8,// corePoolSize：核心线程数
    16,                // maximumPoolSize：最大线程数
    60, TimeUnit.SECONDS,   // keepAliveTime：非核心线程空闲存活时间
    new ArrayBlockingQueue<>(1000),
    new ThreadPoolExecutor.CallerRunsPolicy()  // 拒绝策略
);

// CPU 密集型：线程数 ≈ 核数 + 1
int cpu = Runtime.getRuntime().availableProcessors();
// IO 密集型：线程数 ≈ 核数 × (1 + 等待时间/计算时间)''',
    ["照抄线程池参数不匹配业务，出现 OOM 或任务饿死", "用 Executors.newFixedThreadPool，它用的是无界队列，任务堆积到 OOM"],
    "用自定义线程池跑 1000 个任务，观察不同拒绝策略下的行为差异。"),

# ---------------- 模块 6：框架实战 ----------------
"spring-ioc": (
    ["IoC 容器的本质", "Bean 生命周期回调", "依赖注入的三种方式"],
    '''// 构造器注入（推荐）：依赖明确、便于测试、可final
@Service
public class OrderService {
    private final OrderDao dao;
    public OrderService(OrderDao dao) { this.dao = dao; }
}

// Bean 生命周期
@Component
class MyBean implements InitializingBean {
    @PostConstruct void init() { }    // 初始化后
    @PreDestroy  void destroy() { }   // 销毁前
    @Bean(initMethod = "init", destroyMethod = "close")
}''',
    ["滥用字段注入 (@Autowired 字段)，掩盖了类的真实依赖", "知道 Bean 的懒加载与作用域，却不知道循环依赖是怎么解决的"],
    "定义三个互相依赖的 Bean，分别用构造器注入和 setter 注入，观察启动差异。"),

"aop-aspect": (
    ["切点表达式的五种类型", "通知的优先级", "Spring AOP 的限制"],
    '''@Aspect
@Component
class LogAspect {
    // execution 切点：匹配方法执行
    @Around("@annotation(com.demo.Log) && execution(* com.demo.service..*.*(..))")
    public Object around(ProceedingJoinPoint pjp) throws Throwable {
        long start = System.currentTimeMillis();
        try {
            return pjp.proceed();          // 必须调用，否则方法不执行
        } finally {
            System.out.println("耗时 " + (System.currentTimeMillis() - start) + "ms");
        }
    }
}
// Spring AOP 基于代理，只能切 Spring Bean 的方法，无法切 new 出来的对象''',
    ["在切面里忘记调用 proceed()，业务方法被静默跳过", "用 Spring AOP 去切自己 new 的对象，代理不生效却以为是配置问题"],
    "写一个记录方法耗时的切面，作用到整个 service 包并打印结果。"),

"rest-api-design": (
    ["REST 六约束的落地", "状态码的正确使用", "统一响应与错误处理"],
    '''@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @GetMapping("/{id}")
    public ApiResponse<Order> get(@PathVariable Long id) {
        if (id == null) throw new BizException(400, "id不能为空");
        return ApiResponse.ok(orderService.find(id));
    }
}

// 状态码约定
// 200 成功 / 201 已创建 / 400 参数错误 / 401 未认证
// 403 无权限 / 404 不存在 / 409 冲突 / 500 服务端错误''',
    ["所有响应都返回 200，把错误信息塞进 body，客户端无法区分", "PUT 用在幂等操作上却设计成累加语义，破坏幂等性"],
    "设计一个订单 REST 接口文档，含路径、参数、状态码与错误码定义。"),

"transaction": (
    ["ACID 与隔离级别", "@Transactional 的三个坑", "事务失效场景"],
    '''@Service
public class OrderService {
    // 坑3：同类内部方法调用不走代理，事务不生效
    public void outer() { self.inner(); }      // 无效
    public void inner() { }                    // 无代理

    @Transactional(rollbackFor = Exception.class)  // 坑1：默认只回滚 RuntimeException
    public void create() {
        // 坑2：方法不是 public，或被 final 修饰
    }
}
// 正确做法：注入自己、拆到另一个 Bean、或用 TransactionTemplate''',
    ["忘了写 rollbackFor，抛受检异常时事务不回滚", "在事务方法里做远程调用或发消息，长事务拖垮连接池"],
    "写一个转账方法，故意在中途抛异常，验证 rollbackFor 的效果。"),

"redis-cache": (
    ["缓存穿透、击穿、雪崩三板斧", "缓存与数据库的一致性", "序列化选型"],
    '''// 穿透：查不存在的key —— 缓存空值 +布隆过滤器
if (result == null) {
    result = redis.opsForValue().get(key);
    if (result == null) {
        result = db.query(key);
        if (result == null) {
            redis.opsForValue().set(key, "NULL", 10, TimeUnit.MINUTES); // 空值短TTL
        }
    }
}

// 雪崩：大量 key 同时过期 —— TTL 加随机抖动
long ttl = 3600 + ThreadLocalRandom.current().nextInt(600);
redis.opsForValue().set(key, value, ttl, TimeUnit.SECONDS);''',
    ["删缓存失败导致数据库与缓存长期不一致，没有补偿机制", "所有 key 用相同 TTL，缓存集体失效把流量全打到数据库"],
    "给一个查询接口加缓存，并用随机 TTL 对比雪崩前后的数据库 QPS 曲线。"),

"jmeter-load": (
    ["压测四件套的搭建", "关注 P95/P99 而非平均值", "避免压测失真的手段"],
    '''// JMeter 测试计划结构
Thread Group (100 线程，Ramp-up 30秒)
  └─ HTTP Request (GET /api/orders)
  └─ Assertion (响应码 200)
  └─ Duration Assertion (< 500ms)
Listeners
  └─ Aggregate Report   // 关注 90%/95% percentile

// 关键指标解读
// TPS：每秒事务数，需随并发上升保持稳定
// P99：99% 的请求在此时长内完成，比平均值更能反映真实体验
// 错误率：压测期间必须为 0，否则数据不可信''',
    ["只看平均值响应时间，掩盖了长尾的糟糕体验", "压测机与被压服务同机，资源争抢导致结果失真"],
    "对一个读接口做阶梯加压（10/50/100 线程），记录 TPS 与 P95 变化并画图。"),

# ---------------- 模块 4 补充：类加载 / GC / 调优 / 字节码 ----------------
"class-loading": (
    ["加载、验证、准备、解析、初始化五阶段", "双亲委派模型与破坏", "类加载时机"],
    '''// 双亲委派：先问父加载器，父搞不定才自己加载
protected Class<?> loadClass(String name, boolean resolve) {
    Class<?> c = findLoadedClass(name);
    if (c == null) {
        try {
            c = parent.loadClass(name, false);   // 1. 父加载器
        } catch (ClassNotFoundException e) { }
        if (c == null) c = findClass(name);      // 2. 自己加载
    }
    return c;
}
// 破坏双亲委派：SPI、OSGi、热部署都靠自定义 ClassLoader''',
    ["以为 Class.forName 一定初始化类，其默认不会执行静态块", "把类名写错导致 ClassNotFoundException，却以为是包路径问题"],
    "自定义一个 ClassLoader，把某个 class 文件字节数组 define 进去，独立加载一份与主类同名的类。"),

"gc-algorithms": (
    ["可达性分析与三色标记", "分代假说与 Minor/Major GC", "CMS 与 G1 的取舍"],
    '''// 三色标记：白=待扫描，灰=已标记未扫描子节点，黑=已完成
// GC Roots
// ├─ 虚拟机栈中引用的对象
// ├─ 静态字段引用的对象
// ├─ 常量池引用的对象
// └─ JNI 引用的对象

// 分代收集
// 新生代 Eden:Survivor8:1 → Minor GC（频繁、代价低）
// 老年代 Full GC（STW 时间长），对象熬过15 次晋升''',
    ["以为 GC 越频繁越健康，频繁 Minor GC 反而说明对象分配太快", "手动调大新生代却忽略业务对象生命周期，导致老年代持续增长"],
    "用 JVisualVM 或 Arthas 的 dashboard 观察分代大小变化，对比两次 GC 之间的分配速率。"),

"jvm-tuning-tools": (
    ["jstat / jmap / jstack 三板斧", "Arthas 的在线诊断", "OOM 后如何取证"],
    '''# 实时观察 GC 与分代
jstat -gcutil <pid> 1000     # 每秒打印，关注 YGC/FGC 次数与耗时

# 导出堆快照（OOM 现场必备）
jmap -dump:live,format=b,file=heap.hprof <pid>

# 线程栈，定位死锁
jstack <pid> > thread.txt

# Arthas 在线诊断（无需重启）
java -jar arthas-boot.jar <pid>
> thread -n 3          # 找最忙的三个线程
> watch MyService doWork '{params}'   # 看方法入参出参''',
    ["只会重启不取证，OOM 现场丢失后无法复现", "导堆快照时忘了加 live，导致文件几十 GB 磁盘被撑爆"],
    "对一个循环抛 OOM 的小程序，复现三次，用jmap 导出快照并用 MAT 分析泄漏对象。"),

"bytecode": (
    ["javap 反编译与字节码结构", "常见指令速查", "用字节码解释语言特性"],
    '''$ javap -c -p Hello.class

// 关键指令
// getstatic / putstatic：读写静态字段
// invokevirtual：调用实例方法
// invokespecial：调用构造器或 super 方法
// invokestatic：调用静态方法
// invokeinterface：调用接口方法（动态派发）

// 解释 i++ 的字节码
iload_1        // 压栈 i
iinc1, 1       // 局部变量 i 自增1
istore_2       // 存入临时变量''',
    ["只会看反编译的 Java 源码，看不出编译器做了哪些优化", "以为字节码顺序等于源码顺序，忽略栈式运算的特点"],
    "用 javap -c 对比 final 方法与普通方法的字节码差异，理解 javac 的优化。"),

"project-memory-leak": (
    ["泄漏的四个典型来源", "堆转储的支配树分析", "定位与修复闭环"],
    '''// 泄漏来源
// 1. 静态集合无限增长
static List<Object> CACHE = new ArrayList<>();
// 2. 监听器未注销
button.addActionListener(e -> ...);   // 忘记 removeListener
// 3. 内部类隐式持有外部实例
// 4. 线程池 / ThreadLocal 未清理

// 定位：MAT 的 Leak Suspects Report
// Dominator Tree → 找出支配最多内存的对象
// Path to GC Roots → 找到是哪条引用链把它挂住了''',
    ["把问题归咎于「JVM 有内存问题」，不区分内存不足与内存泄漏", "用System.gc() 试图释放，其实掩盖了泄漏的真实路径"],
    "写一个往静态 List 无限 add 的程序触发 OOM，用 MAT 分析并修复。"),

# ---------------- 模块 5 补充 ----------------
"lock-mechanisms": (
    ["synchronized 的锁升级过程", "ReentrantLock 的独占与共享", "公平锁与非公平锁"],
    '''// synchronized 锁升级：偏向 → 轻量级（CAS 自旋）→ 重量级（OS 互斥）
synchronized (lockObj) {
    // 临界区
}

// ReentrantLock 提供更丰富的能力
ReentrantLock lock = new ReentrantLock(true);   // true = 公平锁
lock.lock();
try {
    // 业务代码
} finally {
    lock.unlock();      // 必须在 finally 里释放
}
lock.lockInterruptibly();// 可中断的加锁''',
    ["lock() 后忘记 unlock()，通常要写在 finally 里", "认为公平锁性能更好，实际吞吐量明显低于非公平锁"],
    "用两个线程给同一个 int 加 100 万次，用 synchronized 与 ReentrantLock 各跑一次看结果。"),

"thread-pool": (
    ["七个参数的工程含义", "CPU 密集 vs IO 密集的差异化配置", "拒绝策略的选择"],
    '''ThreadPoolExecutor pool = new ThreadPoolExecutor(
    8,                         // corePoolSize：核心线程数
    16,                        // maximumPoolSize：最大线程数
    60, TimeUnit.SECONDS,      // keepAliveTime：非核心线程空闲存活时间
    new ArrayBlockingQueue<>(1000),
    new ThreadPoolExecutor.CallerRunsPolicy()  // 拒绝策略
);

// 提交顺序：先核心 → 再入队 → 再扩到最大 → 最后拒绝
// CPU 密集型：线程数 ≈ 核数 + 1
// IO 密集型：线程数 ≈ 核数 × (1 + 等待时间/计算时间)''',
    ["照抄线程池参数不匹配业务，出现 OOM 或任务饿死", "用 Executors.newFixedThreadPool，它用的是无界队列，任务堆积到 OOM"],
    "用自定义线程池跑 1000 个任务，观察不同拒绝策略下的行为差异。"),

"concurrent-collections": (
    ["ConcurrentHashMap 的分段与桶级锁", "CopyOnWriteArrayList 的适用场景", "原子类与并发集合的分工"],
    '''ConcurrentMap<String, Long> map = new ConcurrentHashMap<>();
// merge 是原子操作，避免「get→加→put」的竞态
map.merge("apple", 1L, Long::sum);

// 读多写极少：写时复制，读完全无锁
CopyOnWriteArrayList<String> cow = new CopyOnWriteArrayList<>();
cow.add("rare");// 每次 add 都复制整个数组

// 计数用原子类，聚合用 LongAdder
LongAdder counter = new LongAdder();
counter.increment();''',
    ["在写多场景用 CopyOnWriteArrayList，每次写都复制数组导致 O(n) 开销", "用 map.put(k, map.get(k)+1) 做累加，忽略了这不是原子操作"],
    "用 ConcurrentHashMap 的 merge 统计 100 个线程各提交词频，验证无数据丢失。"),

"project-parallel-aggregate": (
    ["CompletableFuture 的编排模式", "allOf / anyOf 的语义", "自定义线程池隔离"],
    '''ExecutorService bizPool = Executors.newFixedThreadPool(8);

CompletableFuture<A> fa = CompletableFuture.supplyAsync(this::fetchA, bizPool);
CompletableFuture<B> fb = CompletableFuture.supplyAsync(this::fetchB, bizPool);
CompletableFuture<C> fc = CompletableFuture.supplyAsync(this::fetchC, bizPool);

// 并行执行三个任务，任一失败则整体失败
Result r = CompletableFuture.allOf(fa, fb, fc)
        .thenApply(v -> new Result(fa.join(), fb.join(), fc.join()))
        .get(5, TimeUnit.SECONDS);

// 注意：指定自定义线程池，避免用 ForkJoinPool.commonPool 被其他任务打满''',
    ["用 ForkJoinPool.commonPool 跑阻塞式 IO，拖垮所有并行流任务", "用了 allOf 就以为会等全部结果，忘了后还要 join 各自的 future"],
    "并行拉取三个数据源再聚合成一个对象，加上超时与降级兜底。"),

# ---------------- 模块 6 补充 ----------------
"spring-boot-init": (
    ["自动配置的原理与条件注解", "Starter 与依赖管理", "配置文件与多环境配置"],
    '''// 启动类
@SpringBootApplication   // = @Configuration + @EnableAutoConfiguration + @ComponentScan
public class Application { public static void main(String[] args) {
    SpringApplication.run(Application.class, args);
}}

// 条件装配：只有当类不存在且 Bean 未注册时才生效
@ConditionalOnMissingBean(DataSource.class)
@ConditionalOnClass(EmbeddedDatabaseType.class)
@Configuration
public class DataSourceAutoConfiguration { }

// 多环境
// application.yml            公共配置
// application-dev.yml        开发环境
// application-prod.yml       生产环境
spring.config.activate.on-profile: dev''',
    ["随手用 @ComponentScan 扫描整个依赖包，把第三方 jar 全扫进来", "把密码硬编码在 application.yml 提交到仓库"],
    "自定义一个 @ConditionalOnProperty 的自动配置类，用 starter 方式引入并在 yml 里开关。"),

"kingbase-persistence": (
    ["JDBC 驱动的选择与连接参数", "Spring JDBC 与 MyBatis 的取舍", "连接池与事务配置"],
    '''spring:
  datasource:
    url: jdbc:kingbase8://127.0.0.1:54321/javacourse?currentSchema=public&characterEncoding=UTF-8
    driver-class-name: com.kingbase8.Driver
    username: javacourse_app
    password: ${DB_PW}        # 密码走环境变量，不入库
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000

# Key: characterEncoding=UTF-8 必填，否则中文乱码
# currentSchema=public 避免表名解析歧义''',
    ["连接串不写 characterEncoding=UTF-8，中文全部乱码", "密钥明文写进配置文件并提交到版本库"],
    "用 Spring JDBC 写一个最小 CRUD 接口，验证中文读写无乱码。"),

"restful-api": (
    ["REST 六约束的落地", "状态码的正确使用", "统一响应与错误处理"],
    '''@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @GetMapping("/{id}")
    public ApiResponse<Order> get(@PathVariable Long id) {
        if (id == null) throw new BizException(400, "id 不能为空");
        return ApiResponse.ok(orderService.find(id));
    }
}

// 状态码约定
// 200 成功 / 201 已创建 / 400 参数错误 / 401 未认证
// 403 无权限 / 404 不存在 / 409 冲突 / 500 服务端错误''',
    ["所有响应都返回 200，把错误塞进 body，客户端无法区分", "PUT 用在幂等操作上却设计成累加语义，破坏幂等性"],
    "设计一个订单 REST 接口文档，含路径、参数、状态码与错误码定义。"),
}


def build_body(title, summary, concepts, code, pitfall, exercise):
    """把五段要素拼成 Markdown 正文"""
    parts = ["## 本节要点\n", summary + "\n"]
    parts.append("\n## 核心概念\n")
    for c in concepts:
        parts.append(f"- {c}\n")
    parts.append("\n## 关键代码\n")
    parts.append(f"```{'' }\n{code}\n```\n")
    parts.append("\n> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。\n")
    parts.append("\n## 常见误区\n")
    parts.append(f"- {pitfall}\n")
    parts.append("\n## 动手练习\n")
    parts.append(f"{exercise}\n")
    return "".join(parts)


def main():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

    # 读取现有课时的 slug/title/summary
    rows = query("SELECT slug, title, summary FROM lesson ORDER BY id")
    if not rows:
        print("读取课时失败")
        return 1

    updated = 0
    skipped = []
    for slug, title, summary in rows:
        item = CONTENT.get(slug)
        if not item:
            skipped.append(slug)
            continue
        concepts, code, pitfall, exercise = item
        body = build_body(title, summary, concepts, code, pitfall, exercise)
        esc = body.replace("'", "''")
        query(
            "UPDATE lesson SET content = '%s' WHERE slug = '%s'" % (esc, slug),
            write=True,
        )
        # 同步刷新搜索索引，让新正文可被检索
        esc_i = body.replace("'", "''")
        query(
            "UPDATE search_index SET body_text = '%s' WHERE target_type = 'LESSON' "
            "AND target_id = (SELECT id FROM lesson WHERE slug = '%s')" % (esc_i, slug),
            write=True,
        )
        updated += 1

    print("已更新正文: %d / %d" % (updated, len(rows)))
    if skipped:
        print("缺少定制内容(仍用原摘要): %s" % ", ".join(skipped[:10]))
    return 0


def query(sql, write=False):
    """通过 Java 单文件模式执行 SQL，规避 Python 无KingBase 驱动的问题"""
    java_src = os.path.join(
        os.environ.get("TEMP", "/tmp"), "KbQ.java"
    )
    sql_file = os.path.join(os.environ.get("TEMP", "/tmp"), "KbQ.sql")
    #放到纯 ASCII 路径下
    ascii_dir = "C:/Users/%s/kbtmp" % os.environ.get("USERNAME", "lxy")
    subprocess.run(["mkdir", "-p", ascii_dir], shell=False, capture_output=True)
    java_src = ascii_dir + "/KbQ.java"
    sql_file = ascii_dir + "/KbQ.sql"

    with open(sql_file, "w", encoding="utf-8") as f:
        f.write(sql)

    with open(java_src, "w", encoding="utf-8") as f:
        f.write(
            '''import java.sql.*; import java.nio.charset.StandardCharsets; import java.nio.file.*;
public class KbQ {
  public static void main(String[] a) throws Exception {
    String sql=new String(Files.readAllBytes(Paths.get(a[3])), StandardCharsets.UTF_8).trim();
    if(sql.endsWith(";")) sql=sql.substring(0,sql.length()-1);
    try(Connection c=DriverManager.getConnection("jdbc:kingbase8://"+a[0]+":"+a[1]+"/"+a[2]+"?characterEncoding=UTF-8",a[4],a[5]);
        Statement s=c.createStatement()){
      boolean hasRs = s.execute(sql);
      if(hasRs){ ResultSet rs=s.getResultSet();
        ResultSetMetaData md=rs.getMetaData(); int n=md.getColumnCount();
        while(rs.next()){
          StringBuilder line=new StringBuilder();
          for(int j=1;j<=n;j++){ if(j>1) line.append("\\t");
            String v=rs.getString(j);
            if(v==null) v="";
            // 换行与制表符会破坏 TSV 解析，统一压平
            line.append(v.replace("\\r"," ").replace("\\n"," ").replace("\\t"," "));
          }
          System.out.println("ROW\\t"+line);
        }
      }
    }
  }
}'''
        )

    # JVM 在中文 Windows 上默认输出 GBK/GB18030，需按对应编码解码
    enc = "gb18030"
    res = subprocess.run(
        [
            "java", "-cp", JDBC_JAR, java_src,
            DB["host"], DB["port"], DB["db"],
            "C:/Users/%s/kbtmp/KbQ.sql" % os.environ.get("USERNAME", "lxy"),
            DB["user"], DB["pw"],
        ],
        capture_output=True,
        encoding=enc,
        errors="replace",
    )
    if res.returncode != 0:
        raise RuntimeError("SQL 执行失败: " + (res.stderr or "")[:400])
    # 解析 ROW\tcol1\tcol2... 格式
    rows = []
    for line in res.stdout.splitlines():
        if line.startswith("ROW\t"):
            rows.append(line[4:].split("\t"))
    return rows


if __name__ == "__main__":
    sys.exit(main())