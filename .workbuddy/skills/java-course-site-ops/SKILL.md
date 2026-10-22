---
name: java-course-site-ops
description: Java 课程介绍网站（Spring Boot 3 + KingbaseES V8 + Vue 3）的运维与扩展技能。用于新增/修改课程内容与数据库结构、接入或切换大模型通道、调整桌宠动画、排查 KingBase 兼容性问题、跑端到端验证、以及向 GitHub 提交改动。本技能应在本仓库被提及「加一节课」「改课程数据」「接 AI」「桌宠不显示」「KingBase 报错」「部署上线」「跑测试」等场景时使用。
agent_created: true
---

# Java 课程网站运维与扩展

本技能服务于 `java-course-site` 仓库。仓库根目录即项目根，所有路径相对该根目录。

## 项目速览

| 层 | 技术 | 关键位置 |
|---|---|---|
| 后端 | Java 17 target / Spring Boot 3.3.5 / Spring JDBC / Jackson | `backend/` |
| 数据库 | KingbaseES V8R6（PostgreSQL 内核，dbmode=oracle），端口 54321 | `backend/src/main/resources/db/` |
| 前端 | Vue 3.5 + Vite 5 + TS 5.6 + Pinia 2 + vue-router 4（hash 模式） | `frontend/` |
| 鉴权 | PBKDF2-HMAC-SHA256 密码 + 自实现 HMAC-SHA256 会话令牌 | `backend/src/main/java/com/javacourse/security/` |
| AI | 多通道网关 openai → ollama → local（后端）→ offlineReply（前端） | `service/ModelGateway.java` |
| 桌宠 | 悬浮 webm 动画 + Pointer Events 拖拽 + 对话气泡 | `frontend/src/components/FloatingPet.vue` |

**架构要点**：单页应用 + REST API。前端 `hash` 路由（`frontend/src/router/index.ts`），后端 context-path 为 `/api`。后端不引 ORM，直接用 `JdbcTemplate` 手写 SQL。

## 常用命令

```bash
# 后端构建（maven 不在 PATH，必须用 IDEA 内置 maven + 指定 JAVA_HOME）
export JAVA_HOME=D:/develop/Java/jdk-21
"/d/develop/IntelliJ IDEA Community Edition 2024.1.4/plugins/maven/lib/maven3/bin/mvn" -f backend/pom.xml -q package

# 后端启动（打包前先杀掉占用 jar 的旧进程，Windows 文件锁会致 repackage 失败）
Get-CimInstance Win32_Process | Where CommandLine -like '*javacourse-server*' | Stop-Process -Force
java -jar backend/target/javacourse-server.jar

# 前端
cd frontend && npm install && npm run dev      # http://localhost:5173

# 数据库
bash scripts/kb_start.sh      # 启 KingBase
bash scripts/kb_verify.sh     # 验连通
bash scripts/kb_bootstrap.sh  # 建表 + 灌种子数据
```

**默认账号**：`admin / 123456`（由用户指定，勿写入版本库或对外传播）。

## 任务路由

### 新增或修改课程内容

内容链路是「数据库 → Repository → Controller → Vue 视图」。改内容优先改数据而非改代码。

1. 确认目标表：`course` → `course_module` → `lesson` → `code_snippet` / `knowledge_point` / `qa_item` / `resource_file`。
2. 写入数据用 `backend/src/main/resources/db/seed.sql` 的同款 INSERT 风格；slug 必须唯一（`uk_course_slug`、`lesson` 的 slug 同理），它是前端路由参数。
3. 改完重启后端，用 `GET /api/course/list` 与 `GET /api/lesson/{slug}` 验证。
4. 全文检索靠 `search_index` 表 + 应用层分词（`app.search.min-keyword-length`），不依赖数据库分词器。

表结构与字段含义见 `references/database.md`。

### 改数据库结构

1. 只改 `backend/src/main/resources/db/schema.sql`，保持 `-- ============ ` 分节注释风格。
2. 遵循该文件头部的兼容性约束：**避开保留字**（`user` / `level` / `order` / `session` / `comment` / `size` / `type`）、自增主键用 `IDENTITY` 而非序列、时间用 `timestamptz`。
3. KingbaseES V8R6 已实测能力：`tsvector`+GIN、`json`/`jsonb`、`float4[]`、物化视图、窗口函数、`ON CONFLICT` 均可用；**`vector` 扩展与 `zhparser` 不可用**。
4. 迁移已有库时用幂等写法（`DROP ... IF EXISTS` / `CREATE ... IF NOT EXISTS`），本实例 `dbmode=oracle` 对 `IF NOT EXISTS` 支持有限，优先用 `DO $$ BEGIN ... EXCEPTION` 包裹。
5. 改完执行 `bash scripts/kb_bootstrap.sh` 重建并 `bash scripts/kb_verify.sh` 复查。

细节与常见报错见 `references/database.md`。

### 接入 / 切换大模型

网关实现在 `backend/src/main/java/com/javacourse/service/ModelGateway.java`，统一 OpenAI 兼容协议，逐档降级。

- 只改环境变量，不改代码：`AI_PROVIDER`、`AI_BASE_URL`、`AI_API_KEY`、`AI_MODEL`、`AI_FALLBACK_ORDER`、`AI_OLLAMA_BASE_URL`、`AI_OLLAMA_MODEL`、`AI_TIMEOUT_MS`。
- `provider=auto` 时按 `fallback-order` 顺序尝试；某档失败即降级下一档；全失败落 `local`（课程检索式回答）。
- 前端还有最后一级 `offlineReply()`，保证无网络时功能不中断。
- 诊断当前生效通道：调 `GET /api/ai/health`，返回 provider / baseUrl / model / fallbackOrder / openaiConfigured / degraded。

**加一个全新的厂商**：只要它兼容 OpenAI 的 `/v1/chat/completions`，在 `application.yml` 换 `base-url` 即可，无需改代码。厂商 base-url 示例见 `references/ai-gateway.md`。

### 调整桌宠

- 动画文件在 `frontend/public/pet/*.webm`，文件名**必须 ASCII**（中文名在部分客户端返回 400）。
- 状态映射在 `frontend/src/stores/pet.ts` 的 `PET_ANIMATIONS`；新增状态需同时在 `FloatingPet.vue` 的 `switchAnimation()` 与徽章文案中登记。
- 切换动画采用 A/B 双缓冲（两个 `<video>` 交替淡入淡出），新动画先在后台 video 播好再淡入。改动时不要破坏 `front`/`loadedSrc` 的配对逻辑。
- 尺寸：桌面 156px，移动端 116px，`aspect-ratio: 4/5`。素材若四周留白过多会显得很小，用 `scripts/prep_pet_assets.sh` 离线裁切（ffmpeg）。
- 桌宠固定 `z-index: 9999`，气泡方向由 `computeBubbleDir()` 依据上下可用空间切换 `.pet-bubble--down`。
- 前端右下角已有其他悬浮元素时，注意 `.fab` 已移至左侧，避免重叠。

### 视觉与文案

设计系统全部集中在 `frontend/src/styles/design-system.css` 的 CSS 变量：卡通风格、3px 深墨蓝描边（`--c-ink: #2d3561`）、硬边偏移阴影（`--shadow-sm/md/lg`）、糖果色板、圆角 `--radius-*`、字体 `--font-round/--font-body/--font-mono`。

新增界面一律复用这些变量，不要写死颜色与圆角，保证视觉统一。

### 端到端验证

- 桌宠（桌面，16 项断言）：`python scripts/verify_pet.py`
- 桌宠（移动端 iPhone 13 视口，10 项断言）：`python scripts/verify_pet_mobile.py`
- 不接真实大模型时用本地假服务：`python scripts/mock_openai.py`（OpenAI 兼容，19998 端口），再把 `AI_BASE_URL` 指向它。
- Playwright 需用其自带 Chromium（本机无系统 Chrome）。

## 提交与发布

```bash
git add -A && git commit -m "feat: ..."
git push origin master
```

`.gitignore` 已排除 `backend/target/`、`frontend/dist/`、`node_modules/`、`tools/`、`*.zip`、`.env*`。**提交前务必确认没有大文件或依赖目录混入**（`git status` 检查 staged 体积）。

## 已知限制

- KingBase 实例启停需 `SeCreateGlobalPrivilege`（Windows Global 命名对象 `Global\kingbase:`），非管理员账号无法自行启停，需用 `scripts/kb_start.sh` 以授权方式调用。
- 桌宠不能被拖出浏览器视口。
- 未配置 API Key 时，AI 回答来自本地检索式兜底，偏机械。
- 真实云端模型未在本机实测（仅用 mock 验证协议正确性）。

## 参考资料

- `references/database.md` — 表结构、字段语义、KingBase 兼容性与报错速查
- `references/ai-gateway.md` — 模型通道配置、鉴权、延迟与成本、降级链
- `references/frontend.md` — 前端目录、路由、Pinia store、API 封装
