## 本节要点

RESTful 是一组**架构约束**，不是协议。核心约束是：资源用 URI 标识、用 HTTP 方法表达动作、用状态码表达结果、用 JSON 承载数据。好的 RESTful API 应该是**可预测**的——同一个 URI 在任何地方都表示同一个东西。

## 核心概念

- **资源（Resource）**：名词。用 URI 标识，不用动词。
- **HTTP 方法语义**：GET 查、POST 增、PUT 全量改、PATCH 部分改、DELETE 删。**GET 必须安全**（不改状态），**PUT/DELETE 必须幂等**。
- **状态码分类**：
  - 2xx 成功：200 OK、201 Created（带 Location 头）、202 Accepted（异步）、204 No Content
  - 3xx 重定向：301 永久、302 临时、304 未修改（配合 ETag）
  - 4xx 客户端错误：400 参数错误、401 未认证、403 无权限、404 不存在、409 冲突、422 语义错误、429 限流
  - 5xx 服务端错误：500 内部错误、502 网关错误、503 服务不可用、504 网关超时
- **HATEOAS**：通过响应中的链接告诉客户端下一步能做什么（`_links`）。
- **版本化**：URL 路径（`/api/v1/...`）vs 请求头（`Accept: application/vnd.x.v1+json`）。路径版本更直观，实践更常用。
- **幂等性**：同一请求执行多次与执行一次效果相同。PUT/DELETE 必须幂等，POST 默认不幂等（需幂等键）。
- **分页**：offset 分页（简单但深分页慢）与 cursor 分页（keyset，深分页友好）。
- **统一响应格式**：固定结构便于客户端处理。
- **内容协商**：`Accept` 请求期望的格式，`Content-Type` 响应的格式。
- **条件请求**：ETag + If-None-Match、Last-Modified + If-Modified-Since，实现 304。
- **软删除**：DELETE 只标记 `deleted_at`，保留数据。

## 关键代码

```java
@RestController
@RequestMapping("/api/lessons")
public class LessonController {

    // GET：安全、幂等、只读
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<LessonVo>> get(@PathVariable Long id) {
        return lessonService.findById(id)
                .map(l -> ResponseEntity.ok(ApiResponse.ok(LessonVo.from(l))))
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(ApiResponse.fail("LESSON_NOT_FOUND", "课时不存在")));
    }

    // POST：创建，返回 201 + Location
    @PostMapping
    public ResponseEntity<ApiResponse<LessonVo>> create(@Valid @RequestBody CreateLessonRequest req) {
        LessonVo vo = lessonService.create(req);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}").buildAndExpand(vo.id()).toUri();
        return ResponseEntity.created(location).body(ApiResponse.ok(vo));
    }

    // PUT：全量替换，幂等
    @PutMapping("/{id}")
    public ApiResponse<Void> update(@PathVariable Long id, @Valid @RequestBody UpdateLessonRequest req) {
        lessonService.update(id, req);
        return ApiResponse.ok();
    }

    // PATCH：部分更新
    @PatchMapping("/{id}")
    public ApiResponse<Void> patch(@PathVariable Long id, @RequestBody Map<String, Object> patch) {
        lessonService.patch(id, patch);
        return ApiResponse.ok();
    }

    // DELETE：幂等（删不存在的也返回 204）
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        lessonService.softDelete(id);
        return ResponseEntity.noContent().build();
    }

    // 分页 + 过滤
    @GetMapping
    public ApiResponse<PageResult<LessonVo>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String keyword) {
        return ApiResponse.ok(lessonService.page(page, size, keyword));
    }
}

// 统一响应格式
public record ApiResponse<T>(int code, String message, T data, long timestamp) {
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(0, "success", data, System.currentTimeMillis());
    }
    public static <T> ApiResponse<T> fail(String code, String message) {
        return new ApiResponse<>(-1, message, null, System.currentTimeMillis());
    }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- URI 里用动词——`/getUserList`、`/createOrder` 应改为 `/users`、`/orders`
- 所有响应都返回 200，用 body 里的 code 表达错误——破坏了 HTTP 语义
- GET 请求里有副作用（删除、修改）——违反安全性约束
- 忘记分页——全量返回在数据增长后必然拖垮服务
- PUT 不幂等——重复调用产生重复数据
- 错误地把业务错误码与 HTTP 状态码混用

## 动手练习

为课程设计一套 RESTful 接口：列出课时、查看详情、标记完成、收藏，并用 curl 验证状态码与幂等性。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《Offer来了：Java面试核心知识点精讲. 原理篇》《面渣逆袭-分布式篇》《深入浅出Java+23种设计模式》《面试题-15-消息中间件MQ面试题》对 REST 规范、幂等性、分布式场景下的 API 设计有系统论述。

**《Offer来了》原理篇的 RESTful 章节**

《Offer来了：Java面试核心知识点精讲. 原理篇》开篇即讲 JVM 原理、Java 基础、多线程、数据结构、分布式缓存、设计模式等，其中 RESTful 设计给出的原则与本节一致：

- **URL 用名词**：资源用复数形式（`/users` 而不是 `/user`、`/getUser`）
- **HTTP 方法表达动作**：不用自定义动词（`/users/list` 改为 `GET /users?role=admin`）
- **状态码语义化**：不要所有情况都返回 200

**幂等性的工程价值**

《面渣逆袭-分布式篇》把幂等性放在分布式章节里讨论，因为它是分布式可靠性的基石：

```sql
-- 幂等键实现（配合唯一约束）
INSERT INTO payment (order_id, idempotent_key, amount)
VALUES (?, ?, ?)
ON CONFLICT (idempotent_key) DO NOTHING;
```

书中指出幂等键（Idempotency Key）的标准做法：

1. 客户端为每个业务操作生成唯一键（如 UUID）
2. 服务端用该键做唯一约束插入
3. 重复请求命中约束 → 返回首次的结果，不重复执行

这正好是本项目 `learning_progress` 表用 `ON CONFLICT (user_id, lesson_id) DO UPDATE` 的思路——`sessionKey` 扮演了幂等键的角色。

**HTTP 方法的安全性与幂等性对照**

《深入浅出Java+23种设计模式》与《Offer来了》都给出这张表：

| 方法 | 安全 | 幂等 | 典型用途 |
| --- | --- | --- | --- |
| GET | ✔ | ✔ | 查询 |
| POST | ✘ | ✘ | 创建 |
| PUT | ✘ | ✔ | 全量替换 |
| PATCH | ✘ | ✘（视实现） | 部分更新 |
| DELETE | ✘ | ✔ | 删除 |

**幂等不等于安全**：DELETE 不安全（会改状态）但幂等（删多次与删一次效果相同）。

**CAP 原则与 API 设计**

《面渣逆袭-分布式篇》开篇讲 CAP 定理（一致性 C、可用性 A、分区容错性 P，最多满足两个），这与 API 设计的关系是：**在分区必然发生的分布式系统里，接口必须能处理「调用方重试」**。因此写接口时若不做幂等设计，等于把重试的风险推给了调用方。

书中还讲「异步确保型事务」（outbox / 事务消息）：先在本地事务里写消息表，再异步投递，保证「本地事务成功但消息发送失败」这类不一致不会发生。

**REST 与状态码的实战约定**

《面渣逆袭-分布式篇》在讨论消息队列的「幂等性」时也提到 HTTP 层的一致做法：

| 场景 | 状态码 | 说明 |
| --- | --- | --- |
| 创建成功 | 201 | 带 Location 头 |
| 异步处理中 | 202 | 立即返回，后续查状态 |
| 删除成功 | 204 | 无 body |
| 参数格式错误 | 400 | |
| 未认证 | 401 | 带 WWW-Authenticate |
| 已认证但无权限 | 403 | |
| 资源不存在 | 404 | |
| 状态冲突 | 409 | 如重复提交 |
| 触发限流 | 429 | 带 Retry-After |
| 服务端异常 | 500 | |
| 依赖服务不可用 | 503 | 带 Retry-After |

**401 vs 403 的区别**是高频考点：401 是「你是谁？我不知道」，403 是「我知道你是谁，但你不能做这个」。

**HATEOAS 与超媒体**

《深入浅出Java+23种设计模式》与《Offer来了》都提到 REST 的第六条约束（统一接口）背后的理念——**把状态机暴露给客户端**：

```json
{
  "data": { "id": 1001, "status": "CREATED" },
  "_links": {
    "self":    { "href": "/api/orders/1001" },
    "pay":     { "href": "/api/orders/1001/payment", "method": "POST" },
    "cancel":  { "href": "/api/orders/1001/cancel",  "method": "POST" }
  }
}
```

客户端只需看 `_links` 就知道下一步能做什么，不必硬编码状态机逻辑。

**版本化的取舍**

《面渣逆袭-分布式篇》与《Offer来了》都指出：

- **URL 版本**（`/api/v1/users`）：直观、易调试、便于灰度，实践中最常用
- **请求头版本**（`Accept: application/vnd.api.v1+json`）：更"纯粹"（同一资源多个表示），但调试与网关配置复杂
- 兼容性原则：**新增字段永远兼容，删除/改名字段需要大版本**

**Spring Boot 3 的 API 错误处理**

本项目已在用 `@RestControllerAdvice` 做统一异常处理（见异常处理课时）。《面渣逆袭 Spring 篇》指出这与 REST 规范配合时的要点：

- 业务异常 → 4xx + 业务错误码
- 系统异常 → 500 + 通用提示（**不要把堆栈返回给客户端**）
- 参数校验失败 → 400 + 字段级错误信息

## 实战提示

**统一响应结构的建议**：

```java
public record ApiResponse<T>(int code, String message, T data, long timestamp) {
    public static <T> ApiResponse<T> ok(T data) { ... }
    public static <T> ApiResponse<T> fail(String code, String message) { ... }
}
```

注意：**HTTP 状态码与 body 里的 code 要各司其职**——HTTP 状态码表达协议层结果（给中间件、网关看），body 的 code 表达业务语义（给前端判断）。

**幂等键的落地写法**：

```java
@PostMapping("/orders")
public ResponseEntity<ApiResponse<OrderVo>> create(
        @RequestHeader(value = "Idempotency-Key", required = false) String key,
        @Valid @RequestBody CreateOrderRequest req) {
    OrderVo vo = orderService.createWithIdempotency(key, req);
    return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(vo));
}
```

**分页响应的标准结构**：

```json
{
  "code": 0,
  "data": {
    "items": [],
    "page": 0, "size": 20, "total": 42,
    "hasNext": true
  }
}
```

**设计 API 时的自查清单**：

- [ ] URI 是名词复数，没有动词
- [ ] GET 绝不修改数据
- [ ] PUT / DELETE 幂等（重复调用效果相同）
- [ ] 状态码语义正确，不是清一色 200
- [ ] 有分页（且支持上限保护）
- [ ] 错误响应不泄露内部细节
- [ ] 写操作考虑幂等键
- [ ] 时间格式统一 ISO-8601，时区明确
