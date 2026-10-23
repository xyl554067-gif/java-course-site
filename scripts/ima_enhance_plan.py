# -*- coding: utf-8 -*-
"""
批量从 ima 知识库检索课程增强素材。

流程：对每个主题调用 ima search_knowledge（结果落盘）→ 用 extract_ima_hits 提取高相关条目。
输出：一份 Markdown 素材文件，供人工/模型整理成课时正文。

注意：search_knowledge 每次返回约 10 万字符会触发工具落盘，
这里直接读取落盘文件，只把高相关条目的片段抽出来，避免撑爆上下文。
"""
import json, os, subprocess, sys, time, glob

TOOL_DIR = r"C:\Users\lxy\.workbuddy\projects\d-code-PythonApplication1-2026-10-22-10-05-58\a9ce1ddb-c68f-4615-8058-0f1ef11f0f6f\tool-results"
PY = r"C:\Users\lxy\.workbuddy\binaries\python\versions\3.13.12\python.exe"
EXTRACT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_ima_hits.py")
KB_ID = "ima_kb_4skUafXB"

# (slug, 课时标题, 检索 query, 期望命中的资料关键词)
TOPICS = [
    # ---------- 模块 4：JVM ----------
    ("jvm-memory", "JVM 内存结构全景",
     "JVM 内存结构 堆 虚拟机栈 本地方法栈 程序计数器 方法区 元空间",
     "JVM,虚拟机"),
    ("object-layout", "对象内存布局与分代",
     "对象内存布局 对象头 mark word 实例数据 对齐字节 指针压缩 分代",
     "JVM,对象"),
    ("class-loading", "类加载机制全链路",
     "类加载过程 加载 验证 准备 解析 初始化 双亲委派 类加载器",
     "类加载,JVM"),
    ("gc-algorithms", "垃圾回收算法与分代收集",
     "垃圾回收算法 标记清除 标记整理 复制算法 分代收集 CMS G1",
     "GC,垃圾,JVM"),
    ("jvm-tuning-tools", "JVM 调优实战与工具箱",
     "jstat jmap jstack jconsole 内存分析 GC 日志 调优参数",
     "JVM,调优,jstat"),
    ("bytecode", "字节码结构与执行引擎",
     "字节码 栈帧 操作数栈 方法指令 class 文件结构 执行引擎",
     "字节码,JVM"),
    ("project-memory-leak", "实战：排查 JVM 内存泄漏",
     "内存泄漏 排查 内存快照 MAT 分析 dump 堆转储",
     "内存,JVM,泄漏"),
    # ---------- 模块 5：并发 ----------
    ("thread-basics", "线程基础与生命周期",
     "线程 生命周期 状态转换 创建方式 线程安全 可见性 原子性",
     "线程,并发,多线程"),
    ("lock-mechanisms", "锁机制：synchronized 与 Lock",
     "synchronized ReentrantLock AQS CAS 锁升级 可重入 公平锁",
     "锁,synchronized,AQS"),
    ("thread-pool", "线程池原理与实践",
     "线程池 ThreadPoolExecutor 核心参数 拒绝策略 任务队列 复用",
     "线程池,ThreadPoolExecutor"),
    ("concurrent-collections", "并发集合的原理",
     "ConcurrentHashMap CopyOnWriteArrayList 原子类 分段锁 CAS",
     "ConcurrentHashMap,并发,集合"),
    ("completablefuture", "CompletableFuture 异步编排",
     "CompletableFuture 异步编排 thenApply allOf 异常处理 线程池",
     "CompletableFuture,异步"),
    # ---------- 模块 3：集合 ----------
    ("collection-overview", "Collection 体系全景图",
     "Collection List Set Map 体系 面试 区别 ArrayList LinkedList",
     "集合,Collection,List"),
    ("arraylist-source", "ArrayList 源码剖析",
     "ArrayList 源码 扩容 grow 数组复制 elementData",
     "ArrayList,数组,扩容"),
    ("hashmap-red-black-tree", "HashMap 的红黑树",
     "HashMap 源码 put hash 扰动 红黑树 树化 冲突 负载因子",
     "HashMap,红黑树,hash"),
    ("concurrenthashmap", "ConcurrentHashMap 的线程安全",
     "ConcurrentHashMap 原理 CAS synchronized 桶 synchronized",
     "ConcurrentHashMap,并发"),
    ("set-family", "Set 家族：HashSet 与 TreeSet",
     "HashSet TreeSet LinkedHashSet 底层 红黑树 比较器",
     "Set,TreeSet,HashSet"),
    ("iterator-cmc", "迭代器与快速失败机制",
     "迭代器 Iterator fail-fast ConcurrentModificationException 快速失败",
     "迭代器,Iterator,快速失败"),
    ("stream-api", "Stream API 与函数式编程",
     "Stream API 流水线 惰性求值 中间操作 终止操作 Collectors",
     "Stream,函数式,Collector"),
    # ---------- 模块 2：面向对象 ----------
    ("class-and-object", "类的设计与对象生命周期",
     "面向对象 类的设计 对象生命周期 equals hashCode 不可变对象",
     "面向对象,equals,类"),
    ("oop-core", "封装、继承与多态",
     "封装 继承 多态 重写 重载 协变 向上转型 原则",
     "继承,多态,重写"),
    ("interface-vs-abstract", "接口与抽象类怎么选",
     "接口 抽象类 区别 default 方法 多个继承 面向接口编程",
     "接口,抽象类"),
    ("final-static-immutable", "final、static 与不可变对象",
     "final static 不可变对象 Immutable 防御性拷贝 线程安全",
     "final,不可变,static"),
    ("enum-and-record", "枚举与 records",
     "enum 枚举 内部类 record 密封类 sealed switch 模式匹配",
     "enum,record,枚举"),
    ("inner-class-and-lambda", "内部类与 Lambda",
     "内部类 静态内部类 Lambda 函数式接口 方法引用 闭包",
     "内部类,Lambda,函数式"),
    ("exception-handling", "异常处理与实战",
     "异常体系 try-catch-finally 受检异常 非受检 异常链 自定义异常",
     "异常,try,finally"),
    ("generics-type-erasure", "泛型与类型擦除",
     "泛型 类型擦除 桥方法 泛型数组 PECS 通配符",
     "泛型,擦除,PECS"),
    ("reflection-annotation", "反射与注解机制",
     "反射 Class Method 注解 运行时 元注解 动态代理",
     "反射,注解,代理"),
    # ---------- 模块 1：基础 ----------
    ("variables-and-types", "变量类型与运算符",
     "基本类型 包装类型 自动装箱 类型转换 整数缓存 精度",
     "包装,装箱,类型"),
    ("operators", "运算符与表达式",
     "运算符 优先级 位运算 短路 求值 三元 数值转换",
     "运算符,位运算"),
    ("control-flow", "控制流：if、switch 与循环",
     "if switch for while break continue 标签 模式匹配 switch",
     "switch,循环,break"),
    ("arrays", "数组与一维多维数组",
     "数组 初始化 遍历 Arrays 排序 二分 拷贝 数组是引用",
     "数组,Arrays,排序"),
    ("string", "字符串与 String 家族",
     "String 不可变 字符串常量池 StringBuilder StringBuffer equals intern",
     "String,字符串,常量池"),
    ("methods", "方法与参数传递",
     "方法 参数传递 值传递 引用传递 重载 可变参数 递归",
     "方法,传参,重载"),
    # ---------- 模块 6：工程 ----------
    ("spring-boot-init", "Spring Boot 项目初始化",
     "Spring Boot 启动流程 自动装配 注解 依赖注入 Bean 生命周期",
     "Spring Boot,自动装配,Bean"),
    ("kingbase-persistence", "在 KingBase 上持久化",
     "JDBC JdbcTemplate 事务 索引 性能 数据库 连接池 分页",
     "JDBC,事务,索引,数据库"),
    ("restful-api", "RESTful API 设计规范",
     "RESTful 规范 状态码 分页 版本 幂等 统一响应 异常处理",
     "RESTful,状态码,幂等"),
]


def latest_dump():
    files = glob.glob(os.path.join(TOOL_DIR, "mcp-ima-mcp-search_knowledge-*.txt"))
    return max(files, key=os.path.getmtime) if files else None


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "ima-material")
    os.makedirs(out_dir, exist_ok=True)

    for slug, title, query, kw in TOPICS:
        if only and only != slug:
            continue
        print(f"[检索] {slug} / {title}", flush=True)
        # 通过 mcp 调用在此处不好直接发起，改为读取由外部调用产生的落盘文件
        print(f"    query: {query}")
        print(f"    期望命中关键词: {kw}")


if __name__ == "__main__":
    main()
