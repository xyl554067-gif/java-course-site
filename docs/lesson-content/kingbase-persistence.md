## 本节要点

在 KingbaseES（PostgreSQL 内核）上持久化，核心技术点是 **JDBC + 事务 + 索引 + 分页**。本项目用 Spring JDBC 的 `JdbcTemplate` 直接操作 SQL——相比 ORM 性能可控，也更容易看清数据库真实行为。

## 核心概念

- **JDBC 流程**：加载驱动 → 建立连接 → 创建 Statement → 执行 SQL → 处理 ResultSet → 关闭资源。
- **Connection**：代表一次会话。**必须关闭**，生产环境用连接池（HikariCP）。
- **Statement / PreparedStatement / CallableStatement**：预编译语句能防 SQL 注入并复用执行计划。
- **事务（ACID）**：原子性、一致性、隔离性、持久性。`setAutoCommit(false)` 开启事务。
- **隔离级别**：读未提交 / 读已提交 / 可重复读 / 可串行化。Kingbase 支持 PostgreSQL 的四种隔离级别（读已提交为默认）。
- **Savepoint**：事务内设置保存点，支持部分回滚。
- **索引**：B-tree 索引加速等值与范围查询；**索引会拖慢写入**（每次 INSERT/UPDATE 都要维护）。
- **联合索引的最左前缀规则**。
- **覆盖索引**：查询列全在索引里，无需回表。
- **分页**：OFFSET/LIMIT 深分页性能差（要扫描并丢弃前 N 行），用「游标分页」（keyset pagination）。
- **执行计划**：EXPLAIN / EXPLAIN ANALYZE 看索引是否命中、是否全表扫描。
- **慢查询日志**：定位性能问题的第一手段。
- **批量操作**：JDBC 的 addBatch/executeBatch 显著提升批量插入性能。
- **KingbaseES 与 PostgreSQL 兼容**：支持 `ON CONFLICT`、CTE、窗口函数、`jsonb` 类型。

## 关键代码

```java
// Spring JdbcTemplate：参数绑定，防 SQL 注入
@Repository
public class LessonRepository {
    private final JdbcTemplate jdbc;

    public LessonRepository(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public List<Lesson> findByModule(int moduleId) {
        // ? 是占位符，由驱动做参数绑定
        return jdbc.query("SELECT id, slug, title, duration_min FROM lesson WHERE module_id = ? ORDER BY sort_order",
                (rs, i) -> new Lesson(rs.getLong("id"), rs.getString("slug"),
                        rs.getString("title"), rs.getInt("duration_min")),
                moduleId);
    }

    // 批量插入
    public void batchInsert(List<Lesson> lessons) {
        jdbc.batchUpdate("INSERT INTO lesson (slug, title, duration_min) VALUES (?, ?, ?)",
                lessons, 500, (ps, l) -> {
                    ps.setString(1, l.slug());
                    ps.setString(2, l.title());
                    ps.setInt(3, l.durationMin());
                });
    }
}

// 事务：@Transactional 需要开启事务管理
@Service
public class OrderService {
    @Transactional
    public void create(Order order) {
        repo.insert(order);
        stockRepo.deduct(order);   // 一起成功或一起回滚
    }
}

// 手动控制事务（不依赖 Spring AOP 时）
try (Connection conn = dataSource.getConnection()) {
    conn.setAutoCommit(false);
    try (PreparedStatement ps = conn.prepareStatement(
            "INSERT INTO user_favorite (user_id, lesson_id) VALUES (?, ?) ON CONFLICT DO NOTHING")) {
        ps.setLong(1, userId);
        ps.setLong(2, lessonId);
        ps.executeUpdate();
        conn.commit();
    } catch (SQLException e) {
        conn.rollback();
        throw e;
    }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 字符串拼接 SQL——SQL 注入风险
- 忘记关闭 Connection / ResultSet / Statement——连接池被耗尽
- 认为加了事务就一定安全——隔离级别与并发冲突仍需处理
- 无脑给每个字段建索引——写入性能急剧下降
- 深分页用 OFFSET 100000——扫描成本随偏移量线性增长
- 在事务里做远程调用——长时间持有连接与锁

## 动手练习

用 `EXPLAIN ANALYZE` 对比有索引与无索引的查询计划，观察 Seq Scan 与 Index Scan 的差异。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《MySQL技术内幕：InnoDB存储引擎》《MySQL是怎样运行的：从根儿上理解MySQL》《面试题-09-MySQL数据库面试题》《面渣逆袭 MySQL》对本节原理有很好的迁移价值（B-tree 索引、MVCC、锁机制在 PostgreSQL/Kingbase 中概念一致）。

**B-tree 索引的原理**

《MySQL技术内幕：InnoDB存储引擎》详细讲解了 B+ 树索引的组织方式，KingbaseES（PostgreSQL 内核）用的是 B-tree，原理相通：

- **叶子节点存放数据项并用双向链表串起来**，支持范围扫描的高效性
- **非叶子节点只存键**，因此树更矮，磁盘 IO 次数少
- 高度为 3 的 B-tree 能存约 2000 万条记录（千万级数据表的索引只有 3 层）

《MySQL是怎样运行的》用大量图示讲解了 InnoDB 与 PostgreSQL 在索引实现上的差异：PostgreSQL 的索引项**直接指向堆表中的元组**（需要回表），且**堆表行不按顺序存储**（不像 MySQL 的聚簇索引），所以 PostgreSQL 下的范围查询更依赖索引本身有序。

**最左前缀原则**

《面渣逆袭 MySQL》与《MySQL技术内幕》都强调联合索引 `(a, b, c)` 的使用规则：

| SQL 条件 | 是否能用上索引 |
| --- | --- |
| `WHERE a = 1` | ✔ 只用 a |
| `WHERE a = 1 AND b = 2` | ✔ 用 a, b |
| `WHERE a = 1 AND b = 2 AND c = 3` | ✔ 全用 |
| `WHERE b = 2` | ✘ 失效（跳过了最左列） |
| `WHERE a = 1 AND c = 3` | ✔ 用 a，c 需额外处理 |
| `ORDER BY a, b` | ✔ 利用索引有序性 |

**覆盖索引**

《面渣逆袭 MySQL》指出：当查询的所有列都在索引里时，数据库只需读索引不必回表，称为**覆盖索引**，能显著提升性能：

```sql
-- 若有索引 idx(user_id, lesson_id, study_count)
SELECT lesson_id, study_count FROM learning_progress WHERE user_id = 1;
-- 全部列在索引中 → Index Only Scan
```

本项目的 `learning_progress` 表就有 `(user_id, lesson_id)` 唯一约束（ON CONFLICT 的依据），这个索引同时服务了按用户查全部进度、按用户+课时查单条两种场景。

**MVCC 与隔离级别**

《MySQL是怎样运行的》系统讲解了多版本并发控制（MVCC），PostgreSQL/Kingbase 的实现思路类似：

- 每行数据有 `xmin`（插入事务 ID）与 `xmax`（删除事务 ID）
- 读操作不加锁，读取「对当前事务可见的版本」
- 写操作会创建新版本

《面试题-09-MySQL数据库面试题》列出了四种隔离级别与对应的并发问题：

| 隔离级别 | 脏读 | 不可重复读 | 幻读 |
| --- | --- | --- | --- |
| 读未提交 | 可能 | 可能 | 可能 |
| 读已提交 | 否 | 可能 | 可能 |
| 可重复读 | 否 | 否 | 可能（间隙锁缓解） |
| 可串行化 | 否 | 否 | 否 |

Kingbase 默认是**读已提交**，与 PostgreSQL 一致。

**KingbaseES 的兼容性特色**

本项目已经在用的语法（都是 PostgreSQL 风格）：

```sql
-- 1. UPSERT
INSERT INTO learning_progress (...) VALUES (...)
ON CONFLICT (user_id, lesson_id) DO UPDATE SET
    total_seconds = learning_progress.total_seconds + EXCLUDED.total_seconds,
    study_count  = learning_progress.study_count + CASE
        WHEN EXCLUDED.last_session_key IS NOT NULL
        AND learning_progress.last_session_key IS DISTINCT FROM EXCLUDED.last_session_key
        THEN 1 ELSE 0 END;

-- 2. CTE（公共表表达式）
WITH top_lesson AS (
    SELECT lesson_id, SUM(total_seconds) AS secs
    FROM learning_progress GROUP BY lesson_id
)
SELECT l.title, t.secs FROM top_lesson t JOIN lesson l ON l.id = t.lesson_id
ORDER BY t.secs DESC LIMIT 10;

-- 3. 窗口函数
SELECT lesson_id, total_seconds,
       ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY total_seconds DESC) AS rn
FROM learning_progress;

-- 4. jsonb
SELECT content::jsonb -> 'points' FROM course WHERE id = 1;
```

《面渣逆袭 MySQL》讲到 JSON 处理时会对比 MySQL 的 json 类型与 PostgreSQL 的 `jsonb`——KingbaseES 支持 `jsonb`，且支持 GIN 索引。

**慢查询日志**

《MySQL技术内幕》与《面渣逆袭 MySQL》都把慢查询日志列为性能排查第一手段。KingbaseES 中对应配置：

```
log_min_duration_statement = 500     # 记录超过 500ms 的语句
log_statement = 'all'                # 记录所有语句（临时排查用）
```

**深分页问题**

《面渣逆袭 MySQL》详细分析了深分页为什么慢：`LIMIT 100000, 20` 需要扫描 100020 行并丢弃前 100000 行，偏移量越大越慢。解决方案是**游标分页（keyset pagination）**：

```sql
-- 慢：偏移 100000
SELECT * FROM lesson ORDER BY id LIMIT 20 OFFSET 100000;

-- 快：用上一页最后一个 id 作为游标
SELECT * FROM lesson WHERE id > :lastId ORDER BY id LIMIT 20;
```

本项目的课程列表若要支持深分页，应采用这种方案。

## 实战提示

**必须遵守的几条**：

1. **永远用参数绑定**，绝不拼接 SQL
2. **资源用 try-with-resources**，或用 `JdbcTemplate`（自动管理）
3. **事务方法里不做远程调用**——长时间持有连接和锁
4. **写操作前先看执行计划**：`EXPLAIN ANALYZE`

**索引设计的基本原则**：

```sql
-- 覆盖常见查询：按用户查进度
CREATE INDEX idx_progress_user ON learning_progress(user_id);
-- 高频筛选字段
CREATE INDEX idx_lesson_module ON lesson(module_id, sort_order);
```

**但不要过度索引**：每加一个索引，INSERT/UPDATE/DELETE 都要多维护一份 B-tree。经验值是**单表索引不超过 5 个**。

**连接池配置（本项目已在用）**：

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10      # 经验值：CPU核数 * 2 + 磁盘数
      minimum-idle: 2
      connection-timeout: 10000
      pool-name: kb-pool
```

**排查慢 SQL 的完整流程**：

```sql
-- 1. 找到慢查询
SELECT query, calls, mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 10;

-- 2. 看执行计划
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;

-- 3. 看表与索引使用情况
SELECT schemaname, relname, seq_scan, idx_scan
FROM pg_stat_user_tables
ORDER BY seq_scan DESC;
```

`pg_stat_statements` 需要在 `postgresql.conf` 里开启 `shared_preload_libraries = 'pg_stat_statements'`。KingbaseES 兼容这一扩展。
