-- Curated parts from the two requested Bilibili series.
INSERT INTO learning_video (bvid, source_url, title, uploader) VALUES
    ('BV1wL411L7A3', 'https://www.bilibili.com/video/BV1wL411L7A3/', '【浙江大学】Java入门与进阶 翁恺（全110讲）', '农夫CC'),
    ('BV1TJxCzSEEZ', 'https://www.bilibili.com/video/BV1TJxCzSEEZ/', '黑马程序员 2026 版 AI+Java 零基础全套视频课程', '黑马程序员')
ON CONFLICT (bvid) DO NOTHING;

WITH selections (lesson_slug, bvid, part_number, label, recommendation, sort_order) AS (
    VALUES
    ('hello-world', 'BV1TJxCzSEEZ', 7, 'HelloWorld 的编写与运行', '跟着写出第一个程序，再修改实验室示例的输出文本。', 10),
    ('variables-and-types', 'BV1TJxCzSEEZ', 17, 'Java 的基本数据类型', '先理解八种基本类型，再运行课内示例观察取值范围。', 10),
    ('variables-and-types', 'BV1wL411L7A3', 10, '类型转换', '对照视频试一试整数和浮点数之间的转换。', 20),
    ('operators', 'BV1TJxCzSEEZ', 29, '自增和自减运算符', '看完后分别运行 i++ 和 ++i，比较表达式结果与变量的最终值。', 10),
    ('operators', 'BV1TJxCzSEEZ', 33, '短路逻辑运算符', '在右侧加一条打印语句，观察什么时候右侧表达式会跳过。', 20),
    ('control-flow', 'BV1wL411L7A3', 15, '判断语句', '跟着梳理 if 和 else 分支，再试试临界输入会走哪条分支。', 10),
    ('control-flow', 'BV1TJxCzSEEZ', 41, 'switch 语句', '对照示例观察分支匹配，再加一个默认分支。', 20),
    ('control-flow', 'BV1wL411L7A3', 27, 'for 循环', '修改实验室示例的循环边界，检查首尾两次迭代。', 30),
    ('project-guess-number', 'BV1wL411L7A3', 25, '猜数游戏', '跟着实现反复猜测、大小提示和猜中后退出。', 10),
    ('project-guess-number', 'BV1TJxCzSEEZ', 52, '猜数字小游戏', '用另一个实现对照随机数生成和循环退出条件。', 20),
    ('string', 'BV1TJxCzSEEZ', 127, '字符串比较和遍历', '用内容相同的两个字符串，比较 == 和 equals 的结果。', 10),
    ('string', 'BV1TJxCzSEEZ', 129, 'StringBuilder', '看完后用 append 改写实验室里的循环拼接。', 20),
    ('methods', 'BV1wL411L7A3', 49, '方法的参数', '先理解形参和实参，再修改调用参数观察结果。', 10),
    ('methods', 'BV1TJxCzSEEZ', 78, '数组作为方法参数', '试试修改数组元素和重新赋值给形参，比较调用结束后的结果。', 20),
    ('class-and-object', 'BV1wL411L7A3', 53, '定义类', '先区分类的定义和对象的创建，再为示例类增加一个字段。', 10),
    ('class-and-object', 'BV1TJxCzSEEZ', 91, '构造方法', '给同一个类创建两个对象，比较构造方法为它们设置的初始值。', 20),
    ('oop-core', 'BV1wL411L7A3', 82, '封装', '对照视频，试着把一个公开字段改为私有并在方法内校验。', 10),
    ('oop-core', 'BV1wL411L7A3', 72, '继承', '从父类提取公共行为，再在子类里重写一项。', 20),
    ('oop-core', 'BV1TJxCzSEEZ', 115, '多态调用成员', '用父类类型引用子类对象，预测并验证实际调用的方法。', 30),
    ('interface-vs-abstract', 'BV1TJxCzSEEZ', 119, '接口和抽象类综合案例', '看完后找出案例中适合共享的实现，以及适合定义成接口的行为。', 10),
    ('final-static-immutable', 'BV1TJxCzSEEZ', 97, 'static 成员变量', '创建两个实例，观察静态变量如何被共享。', 10),
    ('final-static-immutable', 'BV1TJxCzSEEZ', 101, 'final 关键字', '对照课内示例区分引用不可重新赋值和对象内容不可变。', 20),
    ('enum-and-record', 'BV1TJxCzSEEZ', 102, '枚举', '先用枚举定义一组固定状态，再读课内 record 示例。', 10),
    ('inner-class-and-lambda', 'BV1TJxCzSEEZ', 123, '静态内部类和匿名内部类', '看完匿名内部类示例，再用课内示例比较它和 Lambda 的写法。', 10),
    ('exception-handling', 'BV1wL411L7A3', 96, '捕捉异常', '先运行会抛异常的输入，再加上对应的 catch 分支。', 10),
    ('exception-handling', 'BV1wL411L7A3', 100, '抛出异常', '练习把输入校验提取到方法中，让调用方处理抛出的异常。', 20),
    ('generics-type-erasure', 'BV1wL411L7A3', 65, '前置：泛型容器', '用泛型限制容器的元素类型，再结合课内示例观察编译后的类型擦除。', 10),
    ('project-grade-system', 'BV1TJxCzSEEZ', 89, '学生类与数据校验', '先完成学生对象及字段校验，再把它用于本站的成绩管理练习。', 10),
    ('collection-overview', 'BV1wL411L7A3', 69, '集合容器 Set', '从元素唯一性入手，再用本课示例比较 List、Set 和 Map。', 10),
    ('arraylist-source', 'BV1TJxCzSEEZ', 133, '前置：ArrayList 的用法', '先熟悉增删查改，扩容和复制过程可结合本站的源码示例。', 10),
    ('hashmap-red-black-tree', 'BV1wL411L7A3', 70, '前置：哈希表', '先理解散列表的查询，再阅读本站关于桶冲突和树化的内容。', 10),
    ('set-family', 'BV1wL411L7A3', 69, 'Set 与元素去重', '先理解集合去重，再运行本课示例比较 HashSet 和 TreeSet 的迭代顺序。', 10),
    ('jvm-memory', 'BV1TJxCzSEEZ', 76, '前置：变量和方法的内存分配', '先跟踪一次方法调用中的变量，再回到课内图解梳理 JVM 各内存区。', 10),
    ('object-layout', 'BV1TJxCzSEEZ', 94, '前置：Java 对象的内存分配', '先区分变量里的引用与对象本身，再对照课内图解学习对象头和对齐。', 10),
    ('bytecode', 'BV1TJxCzSEEZ', 74, '前置：Java 的运行机制', '先理解编译生成的 class 文件如何运行，再按课内步骤用 javap 查看字节码。', 10)
)
INSERT INTO lesson_video (lesson_id, video_id, part_number, label, recommendation, sort_order)
SELECT l.id, v.id, s.part_number, s.label, s.recommendation, s.sort_order
FROM selections s
JOIN learning_video v ON v.bvid = s.bvid
JOIN lesson l ON l.slug = s.lesson_slug
JOIN course_module m ON m.id = l.module_id
JOIN course c ON c.id = m.course_id
WHERE c.slug = 'java-mastery'
ON CONFLICT (lesson_id, video_id, part_number, start_seconds) DO NOTHING;
