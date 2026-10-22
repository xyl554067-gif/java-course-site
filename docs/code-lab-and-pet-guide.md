# Java 练习模块 与 AI 助教桌宠 —— 改动说明与本地验证指南

> 适用版本：2026-10-22 之后
> 涉及模块：代码实验室（示例代码真实运行 / 习题判题）、AI 助教桌宠（生命周期 + 可配置 AI 接口）

---

## 一、问题根因

### 1.1 Java 练习模块

| 现象 | 根因 |
|---|---|
| 示例代码点了没反应，前端也没有运行入口 | 前端只有 `<pre>` 静态展示，没有任何"编辑 / 运行 / 提交"入口；后端也没有任何编译执行能力 |
| 部分示例代码"看起来是 Java 但跑不起来" | **数据库里存的是字面量 `\n`（反斜杠 + 字母 n），不是真换行**。KingbaseES/PostgreSQL 默认 `standard_conforming_strings=on`，SQL 单引号字符串里的 `\n` 就是两个普通字符。写进 `code_text` 的源码因此全被压成一行，javac 必然报语法错误 |
| 编译错误、运行异常、程序输出全都拿不到 | 后端没有代码执行服务 |

### 1.2 AI 助教桌宠

| 现象 | 根因 |
|---|---|
| 关闭对话窗口后再也唤不起来 | `FloatingPet.vue` 的 `onPointerUp()` 里，点击分支直接 `return`，**漏掉了 `pet.setState('idle')`**。上一次 `pointerdown` 置为 `dragging` 后，没有任何路径把它改回 `idle`，状态机永久卡死，后续点击被状态判断拦住 |
| 关闭后历史对话消失 | `stores/pet.ts` 的 `messages` 只是内存 ref，没有任何持久化 |
| 没有接入任何可用 AI 接口 | 只有一条走后端代理的链路，Key 硬编码在服务端配置里；用户无法自行填 API Key 或改后端代理地址；未配置时也没有任何明确提示 |

---

## 二、改动清单

### 2.1 后端（新增 4 个类 + 2 张表）

| 文件 | 作用 |
|---|---|
| `backend/.../service/CodeRunnerService.java` | **代码执行核心**。编译 + 运行 Java 源码，返回结构化结果 |
| `backend/.../service/CodeJudgeService.java` | **判题**。按测试用例逐条执行、比对期望输出、汇总状态并落库 |
| `backend/.../repository/CodeRepository.java` | 习题与提交记录的读写 |
| `backend/.../controller/CodeController.java` | 对外 REST 接口 |
| `backend/.../config/AppProperties.java` | 新增 `app.code` 配置段 |
| `backend/src/main/resources/db/schema.sql` | `code_snippet` 增 3 列；新建 `code_exercise`、`code_submission` 两张表 |

**新增接口**

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/code/runtime` | 环境自检：javac/java 路径与版本、超时/内存/输出上限 |
| POST | `/api/code/run` | 运行任意源码，body `{code, stdin}` |
| POST | `/api/code/submit` | 判题并落库，body `{exerciseId, code}` |
| GET | `/api/code/exercises` | 习题列表（可选 `?lessonId=`） |
| GET | `/api/code/exercises/{slug}` | 习题详情（**不下发参考答案**） |
| GET | `/api/code/submissions` | 我的提交记录（可选 `?exerciseId=`） |

**判题返回状态**：`PASSED` / `FAILED` / `COMPILE_ERROR` / `RUNTIME_ERROR` / `TIMEOUT` / `NOT_FOUND`

**执行模型的几个关键细节**

1. **每次调用建独立临时目录**（`src/` + `classes/`），用完递归删除，学生代码之间不互相污染。
2. **主类名自动推断**：Java 要求 `public class X` 与文件名同名，所以先从源码正则推断类名（优先 public 类，否则第一个顶层类），再决定写进哪个 `.java` 文件。
3. **双线程 drain 输出**：stdout / stderr 各一个线程持续读取，避免管道写满造成死锁。
4. **超时强杀整棵进程树**：`process.descendants().forEach(ProcessHandle::destroyForcibly)`，`while(true)` 不会拖垮服务。
5. **资源约束**：运行期 `-Xmx256m`，stdout/stderr 各自截断到 20000 字符，源码长度上限 100000 字符。
6. **编码全套锁 UTF-8**：
   - 运行期加 `-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dsun.stdout.encoding=UTF-8 -Dsun.stderr.encoding=UTF-8`
     （JDK 18+ `System.out` 走 `stdout.encoding`，只设 `file.encoding` 不够，Windows 默认 GBK 会中文乱码）
   - 编译期给 javac 加 `-J-Dfile.encoding=UTF-8 -J-Dstdout.encoding=UTF-8 -J-Dstderr.encoding=UTF-8`，
     这样 javac 的中文诊断信息（"错误: 不兼容的类型"）也不会乱码。

> ⚠️ **已知边界**：这是教学用的**进程级沙箱，不是安全沙箱**。它限制了 CPU 时间、内存与输出量，但未做文件系统/网络隔离。生产部署请把代码执行放到独立容器或受限 worker。

**新增配置项**（`backend/src/main/resources/application.yml`）

```yaml
app:
  code:
    java-home: ${CODE_JAVA_HOME:}   # 留空则用 CODE_JAVA_HOME → JAVA_HOME → 系统 PATH
    timeout-ms: 10000               # 单次运行上限
    compile-timeout-ms: 15000       # 单次编译上限
    memory-limit-mb: 256            # 运行期堆上限
    max-output-chars: 20000         # stdout/stderr 各自上限
    max-source-chars: 100000        # 源码长度上限
```

### 2.2 数据库

```sql
-- code_snippet 新增
ALTER TABLE code_snippet ADD COLUMN runnable BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE code_snippet ADD COLUMN stdin VARCHAR(2000);
ALTER TABLE code_snippet ADD COLUMN expected_out VARCHAR(2000);

-- 新建
CREATE TABLE code_exercise (
  id ..., lesson_id ..., slug VARCHAR(80) UNIQUE, title, description,
  difficulty, language, starter_code CLOB, solution_code CLOB,
  test_cases CLOB, hint, sort_order
);
CREATE TABLE code_submission (
  id ..., user_id, exercise_id, source_code CLOB, status,
  case_results CLOB, stdout CLOB, stderr CLOB, error_output CLOB,
  passed_count, total_count, duration_ms, created_at
);
```

### 2.3 数据修复与自检：`scripts/seed_code_lab.py`

这个脚本做 5 件事，**第 1 步就是根治 `\n` 问题**：

1. 建表 / 补列
2. **修复字面 `\n`**：
   ```sql
   UPDATE code_snippet SET code_text = replace(code_text, chr(92) || 'n', chr(10));
   ```
   （`chr(92)` 是反斜杠，`chr(10)` 是换行）
3. 写入 21 条**完整可编译**的可运行示例
4. 写入 9 道课后习题（含 `starter_code` / `solution_code` / `test_cases` / `hint`）
5. 校验

`--verify` 参数会用**本机 JDK 真实编译并运行**全部示例与 9 道习题的参考答案：

```bash
python scripts/seed_code_lab.py --verify
# ==> 自检：示例代码
# ==> 自检：习题参考答案
#     通过 50 项，失败 0 项
```

自检过程中发现并修掉的真实缺陷（都是"示例不能跑"的实例）：

- `Boolean.BYTES` 在 Java 中不存在 → 编译失败，改为文字说明"boolean 在 JLS 中未规定固定大小"
- `gc-algorithms` 的 `WeakReference` 期望 `true` 实际 `false`（对象可能已被回收）→ 改写示例逻辑与期望值
- "内存泄漏"示例 `CACHE.size() * 1024 / 1024` = 1000 却标成 MB → 改为输出 KB
- `HashSet` 迭代顺序不确定 → 改用 `TreeSet`
- `thread-pool` / `project-parallel-aggregate` 多线程输出顺序不确定 → `expected_out` 置空（跳过精确断言）

### 2.4 前端

| 文件 | 说明 |
|---|---|
| `frontend/src/components/CodeEditor.vue` | **新建**。零依赖 textarea 编辑器（不引入 CodeMirror/Monaco，避免 MB 级体积）。行号列与代码区 `scrollTop` 同步；Tab 插入 4 空格、Shift+Tab 反缩进、多行选区整体缩进；`Ctrl/Cmd + Enter` 触发运行 |
| `frontend/src/views/ExerciseView.vue` | **新建**。左栏习题列表 + 右栏题面 / 编辑器 / 标准输入 / 运行结果 / 判题明细 / 历史提交 |
| `frontend/src/views/LessonView.vue` | **修改**。课时页"代码实验室"加「▶ 运行」「✎ 在编辑器中打开」按钮、可运行徽标、环境警告条、运行结果块；新增"课后习题"区块 |
| `frontend/src/api/index.ts` | **修改**。新增 `codeApi`（`runtime`/`run`/`submit`/`exercises`/`exercise`/`submissions`）与 5 个类型。`run` 超时放宽到 60s、`submit` 放宽到 120s（全局 30s 不够用） |
| `frontend/src/router/index.ts` | **修改**。新增 `/exercises` 与 `/exercise/:slug` |
| `frontend/src/App.vue` | **修改**。导航新增"代码练习"入口 |

**页面 URL 说明**：本项目用的是 **hash 路由**（`createWebHashHistory`），所以练习页地址是
`http://127.0.0.1:5173/#/exercises`，不是 `http://127.0.0.1:5173/exercises`。

### 2.5 桌宠

| 文件 | 改动 |
|---|---|
| `frontend/src/stores/pet.ts` | **重写**。新增 `PetAiConfig` 与 `DEFAULT_AI_CONFIG`；`loadHistory`/`persistHistory`（key `javacourse.pet.history`，上限 60 条）、`loadConfig`/`persistConfig`/`updateConfig`/`resetConfig`（key `javacourse.pet.aiConfig`）；`callAi(q)` 按模式路由；`callDirect(q)` 浏览器直连 OpenAI 兼容端点并带上文 10 条；`directConfigured` / `effectiveChannel` 计算属性；`clearHistory()`（只清对话不动配置）、`lastError` |
| `frontend/src/components/FloatingPet.vue` | **修改**。① **状态 bug 修复**（见下）；② 新增 `showSettings` / `cfgDraft` 状态与 `openSettings`/`saveSettings`/`cancelSettings`/`resetSettings`/`clearHistory`；③ 模板新增 ⚙ 设置按钮 + `.pet-settings` 面板；④ 样式新增 `.pet-settings*`、`.pet-btn*`、`.is-hidden` |

**状态机 bug 的修复**（关键）

```typescript
if (!dragMoved.value) {
  // ⚠ 状态机收尾必须放在这里：之前这个分支直接 return，
  //   导致 pet.setState('dragging') 之后没有任何路径把它改回 idle
  pet.setState('idle')
  computeBubbleDir()
  pet.openBubble()
  void nextTick(() => focusInput())
  return
}
```

**桌宠 AI 的三种接入模式**

| 模式 | 说明 | 适合 |
|---|---|---|
| `backend`（默认） | 走本项目后端 `/api/ai/ask` 代理，Key 在服务端配置，不进浏览器 | 生产部署 |
| `direct` | 浏览器直连用户填写的 OpenAI 兼容端点，Key 只存本机 `localStorage` | 个人使用 / 快速试用 |
| `local` | 完全不调大模型，走本地预设回复 | 离线演示 |

**未配置时的明确提示**（不配置也能用，不会静默失败）：

- `direct` 模式缺地址或 Key → 桌宠回复
  「呜哇，鲸鲸还没接上你的 AI 接口喵～ 请在气泡右上角的「⚙ 设置」里填写：· 接口地址（OpenAI 兼容，例如 https://api.deepseek.com）· API Key」
- `local` 模式 → 明确告知「当前设置为「仅本地兜底」，未接入任何大模型」
- 后端没配 Key → 走已有的本地兜底链路，并在气泡上标记降级状态

---

## 三、本地验证方式

### 3.0 前置

1. **KingbaseES 已启动**（端口 54321），数据库 `javacourse` 可连
   ```bash
   bash scripts/kb_verify.sh
   ```
2. **本机有 JDK 17+**（推荐 21），`javac` 可用
   ```bash
   javac -version && java -version
   ```
   若 JDK 不在 PATH，设置环境变量指到 JDK 根目录（**根目录，不是 bin**）：
   ```bash
   export CODE_JAVA_HOME=/d/develop/Java/jdk-21
   ```

### 3.1 启动服务

```bash
# 1) 后端（8080）
cd backend
/d/develop/Java/jdk-21/bin/java.exe -jar target/javacourse-server-1.0.0.jar --server.port=8080

# 2) 前端（5173）
cd frontend
npx vite --host 127.0.0.1 --port 5173
```

> 若要重新打包后端（本机 Maven 可能在 IDEA 里）：
> ```bash
> cd backend
> "/d/develop/IntelliJ IDEA Community Edition 2024.1.4/plugins/maven/lib/maven3/bin/mvn" -o -DskipTests package
> ```
> 打包前要先停掉正在运行的后端，否则 jar 被占用会报 `Unable to rename ... jar.original`。

### 3.2 数据自检（最直接的"代码能不能跑"验证）

```bash
python scripts/seed_code_lab.py --verify
```

期望输出结尾：`通过 50 项，失败 0 项`（21 条示例 + 9 道习题参考答案，全部用本机 JDK 真编译真运行）

### 3.3 后端接口验证（12 项断言）

```bash
python scripts/verify_code_api.py
```

覆盖：登录 → 环境自检 → 运行成功（含中文输出不乱码）→ 编译错误 → 运行异常 → 标准输入 → 超时 → 习题列表 → 详情不泄露答案 → 判题 FAILED → 判题 PASSED（用库里的参考答案）→ 提交记录。

期望结尾：`✓ 全部通过`

### 3.4 前端端到端验证（38 项断言，Playwright）

```bash
# 需要先起好前后端
python scripts/verify_code_lab.py
```

覆盖：

**A. Java 练习模块（18 项）**
- 练习页加载、习题列表 9 道、环境自检显示就绪
- 编辑器存在、行号列渲染
- 写正确代码 → 运行 → 真实 stdout（断言输出含 `25`）
- 写错类型 → 显示中文编译错误且**无乱码**
- 空指针 → 显示异常栈含 `NullPointerException`
- 提交判题 → 逐条用例结果、`4 / 4 用例通过`、状态「判题通过」
- 历史提交区块存在
- 课时页示例「▶ 运行」→ 真实输出 `Hello, Java!`
- 「✎ 在编辑器中打开」→ 跳转 `/#/exercise/ex-sum-odd` 且代码带入编辑器

**B. AI 助教桌宠（20 项）**
- 桌宠常驻页面、在视口内
- 第一次点击弹出气泡 → 提问 → 收到回复
- 关闭气泡 → **再次点击仍能唤起**（生命周期修复验证）
- 再次打开后**历史消息仍在**（2 条）、`localStorage` 已写入 1338 字符
- 状态机回到 `idle`（类名不含 `dragging`）
- ⚙ 设置面板打开、三种模式可切换
- 直连模式显示 CORS/隐私警告
- 配置持久化成功
- 刷新页面后历史仍保留
- direct 模式未配置 Key → 桌宠给出明确引导文案
- 「恢复默认」可回到 `backend` 模式
- 控制台无严重报错

期望结尾：`✓ 全部通过（38 项）`

截图落在 `docs/screenshots/`：
`lab-run-success.png` / `lab-compile-error.png` / `lab-judge-passed.png` / `lesson-snippet-run.png` /
`pet-reopen-history.png` / `pet-settings.png` / `pet-direct-unconfigured.png` / `pet-after-reload.png`

### 3.5 手动点验路径

1. 打开 `http://127.0.0.1:5173/`，用 `demo` / `123456` 登录
2. 顶栏「代码练习」→ 左栏选「奇数之和」→ 编辑器里改代码 → 点「▶ 运行」看真实输出
   → 点「✓ 提交判题」看逐条用例结果 → 下方看历史提交
3. 顶栏进任一课时 → 拉到「代码实验室」→ 点示例的「▶ 运行」看真实输出
   → 点「✎ 在编辑器中打开」跳到练习页
4. 右下角桌宠 → 点击唤起 → 问一句 → 点右上角 ⚙ 切换接入方式
   → 点 × 关闭 → **再点桌宠，历史对话还在**

---

## 四、常见问题

| 现象 | 原因与处理 |
|---|---|
| 练习页顶部黄色横幅「未检测到可用的 JDK」 | 后端进程找不到 javac。设 `CODE_JAVA_HOME` 指到 **JDK 根目录**后重启后端；或用 `app.code.java-home` 配置 |
| 运行结果中文乱码 | 确认后端是本仓库的新版本（编译期/运行期编码参数都在 `CodeRunnerService` 里） |
| 判题一直 `COMPILE_ERROR` 但代码看着没问题 | 源码里可能混进了不可见字符（`\u200b` 零宽空格、全角引号）。用「重置代码」按钮恢复起始代码再对比 |
| 提交时提示「未登录或登录已过期」 | token 有效期 12 小时，重新登录 |
| 提交接口报「代码不能为空」 | 后端同时接受 `code` 与 `sourceCode` 两个字段名，若仍报错请确认请求体是 JSON 且带 `Content-Type: application/json` |
| 桌宠点不动 | 老版本前端缓存。硬刷新（Ctrl+F5）确认 `stores/pet.ts` 是新版本 |
| 桌宠直连报 CORS 错误 | 第三方端点不允许跨域浏览器调用。改用「后端代理」模式 |
| 本机有 `http_proxy` 环境变量时本地接口 502 | 代理劫持了 localhost 请求。脚本已强制直连；手工 curl 时加 `--noproxy '*'` |
