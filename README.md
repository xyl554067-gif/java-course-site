# Java 精通之路 ·课程介绍网站

一个卡通风格的 Java 课程介绍站，后端 Spring Boot 3 + KingbaseES V8，前端 Vue 3 + Vite，
内置鲸鲸 AI 助教（全站会动的 Ciallo~ 猫耳女仆形象）。

在线体验（GitHub Pages 免费地址）：[https://xyl554067-gif.github.io/java-course-site/](https://xyl554067-gif.github.io/java-course-site/)

在线登录后端部署说明：[docs/online-login-deployment.md](docs/online-login-deployment.md)。GitHub Pages 只提供前端页面；登录需先部署 API 与 PostgreSQL，再在 `gh-pages` 分支的 `config.js` 中配置 API 地址。

---

## 快速启动

### 前置条件

| 依赖 | 版本 | 说明 |
| --- | --- | --- |
| KingbaseES V8 | V8R6C009B0014 | **必须以管理员权限启动**，原因见下方「重要约束」 |
| JDK | 21（编译目标 17） | 任意 21.x |
| Maven | 3.9+ | `tools/apache-maven-3.9.9`已自带 |
| Node.js | 18+ | 任意 20.x 亦可 |

### 一键启动（Windows）

双击仓库根目录的 `启动Java课程站.bat`。它会检查 KingBase、后端和前端端口，复用已运行的服务；数据库未运行时会请求管理员权限启动本机 KingBase，然后等待 API 健康检查并打开浏览器。构建产物不存在时会给出具体提示。

启动日志位于 `.local-run/logs/`：`database-start.log`、`backend.log`、`backend-error.log`、`frontend.log` 与 `frontend-error.log`。KingBase 需要 UAC 管理员确认；取消后启动器会报告数据库环节未完成。

### 手动启动

```bash
# 1. 确认数据库在跑
bash scripts/kb_start.sh

# 2. 启动后端（端口 8080）
cd backend
mvn -B -DskipTests package
java -jar target/javacourse-server-1.0.0.jar --server.port=8080

# 3. 启动前端（端口 5173）
cd frontend
npm install
npm run dev
```

打开 <http://127.0.0.1:5173>，用`admin` / `123456` 或 `demo` / `123456` 登录。

> ⚠️ 后端启动**必须显式带 `--server.port=8080`**。本机环境里存在 `SERVER_PORT`
> 变量会覆盖配置，导致 Tomcat 随机端口启动。

---

## 重要约束：为什么不能自己启动数据库

KingbaseES V8 的 License 共享内存是 Windows **Global 命名空间内核对象**
（二进制里能提取到 `Global\kingbase:` 前缀，来源 `kdbshmem_win32.c`）。
创建它需要 `SeCreateGlobalPrivilege`—— 实测非管理员令牌下
`CreateFileMappingW` 返回 err 5，`AdjustTokenPrivileges` 返回 1300。

结论：**全局只能跑一个实例，且必须由管理员权限进程启动。**
因此一键启动器只在检测到数据库未运行时请求 UAC 管理员确认，并先检查端口，避免重复启动现有实例。也可手动使用状态检查（`kb_start.sh`）与优雅停库（`kb_stop.sh`）。

数据库启动方式：

```powershell
# 管理员 PowerShell
cd D:\Kingbase\KESRealPro\V008R006C009B0014\Server\bin
.\sys_ctl.exe -D D:\Kingbase\data start
```

**停止时务必用 `sys_ctl stop`，不要 `taskkill`**——强杀不会释放 License 共享内存，
下次启动会报 `FATAL: attach License shared memory error: openfilemapping error`。

---

## 自学、AI 课程生成与个人学习中心

- 课时阅读采用笔记目录布局；课时笔记、独立代码实验室和习题分区，只有存在编程示例的课时才显示代码实验室。代码编辑器在系统明暗主题下使用相应对比度。
- 顶部“AI 课程工坊”支持文本型 PDF、DOCX、PPTX 和无需登录的公开网页。单文件上限 20 MB；扫描版 PDF、旧版 Office 文件和登录网页暂不支持。生成内容先保存为个人私有草稿，可编辑后发布；只读分享链接由本人创建并可撤销。
- AI 课程生成复用鲸鲸助教的模型配置。AI 不可用时仍会根据资料生成可编辑提纲，并提示用户核对补充。
- 顶部“AI 接入”和学习中心可为当前账号配置 OpenAI 兼容 HTTPS 接口地址、模型名与 API Key；小助教和课程工坊共用配置。Key 由后端 AES-GCM 加密后按账号保存，不会返回到浏览器。连接测试会向所填服务发送一条简短测试消息。
- 本地启动器会在忽略的 `.local-run/ai-config-encryption.key` 生成并复用本机加密密钥。Render 配置使用 `AI_CONFIG_ENCRYPTION_KEY` 独立密钥；更换此密钥后，原有账号 Key 将无法解密。
- Render 默认使用 `AI_PROVIDER=auto`，可用服务环境变量配置全站默认模型，也可登录后在“AI 接入”页保存个人模型配置；Key 不放在前端或仓库中。未配置可用模型时会明确降级成资料提纲。
- “学习中心”包含真实学习记录、按日历展示的计时/完成数据、成就、收藏、导入课程与个人资料。学习时长只按可见页面的计时心跳累加，不使用预估时长。
- 新功能需要的私有课程和学习日历表会在后端启动时幂等创建；升级 SQL 也可在 `backend/src/main/resources/db/upgrade-course-builder.sql` 查阅。

---

## 数据库选型：为什么不是非结构化数据库

核心实体是强关系型的：`course → course_module → lesson → code_snippet`、
`app_user → learning_progress / user_favorite`、`ai_chat_session → ai_chat_message`，
需要事务、外键与聚合统计。改用 NoSQL 会丢掉这些保证。

半结构化诉求（Markdown 正文、代码块、知识点卡片、embedding）用 KingBase 自带能力承载即可。
本机 V8R6 实测结论：

| 能力 | 支持 |
| --- | --- |
| `tsvector` + GIN 全文检索 | ✅ |
| `json` / `jsonb` + `->>` | ✅ |
| 数组类型、`float4[]`、数组切片、`array_length` | ✅ |
| 物化视图、窗口函数、`ON CONFLICT` | ✅ |
| `vector` 扩展（pgvector） | ❌ `share/extension/vector` 不存在 |
| `zhparser` 中文分词 | ❌ 需 superuser 权限 |

因此路线是：**关系型为主 + jsonb 文档列 + embedding 存 `float4[]` 应用层算余弦**。
真到万级课时需要纯语义召回时，在应用层外挂向量服务即可，业务表结构一行不用改。

中文搜索目前走应用层分词（整串 + 英文词 + 中文单字/双字滑窗），
这是刻意选择：无 `zhparser` 时反而比数据库分词更可控，且中英混排查询
（如「int和long有什么区别」）能正常召回。

---

## 数据库结构

17 张表，位于 `backend/src/main/resources/db/schema.sql`：

**内容域** — `course`、`course_module`、`lesson`、`code_snippet`、`knowledge_point`、
`lesson_knowledge`、`qa_item`、`resource_file`、`search_index`

**用户域** — `app_user`、`user_session`、`learning_progress`、`user_favorite`

**AI 域** — `ai_chat_session`、`ai_chat_message`、`generation_log`

种子数据（`seed.sql`）：1 门课程 / 6 个模块 / 42 个课时 / 14 段代码 / 27 个知识点 / 48 条搜索索引。

课时正文由 `scripts/enrich_content.py` 增强为五段式结构化 Markdown
（本节要点 / 核心概念 / 关键代码 / 常见误区 / 动手练习），平均正文长度从 72 字提升到 658 字，
并同步刷新 `search_index.body_text` 保证可检索。重新初始化数据库后执行它即可补齐：

```bash
python scripts/enrich_content.py
```

重建全部数据：

```bash
bash scripts/kb_bootstrap.sh   # ⚠会 DROP 重建 javacourse 库
bash scripts/kb_verify.sh      # 只读校验行数与中文编码
```

连接配置的唯一事实来源是 `scripts/kb_env.sh`，改端口/口令只改那里。

---

## 后端接口

统一响应包装 `{ code, message, data }`，`code=200` 为成功。

| 方法 | 路径 | 需登录 | 说明 |
| --- | --- | --- | --- |
| GET | `/api/health` | 否 | 健康检查，探测数据库 |
| POST | `/api/auth/register` | 否 | 注册，返回 token |
| POST | `/api/auth/login` | 否 | 登录，返回 token |
| POST | `/api/auth/logout` | 否 | 登出 |
| GET | `/api/auth/me` | 是 | 当前用户 |
| GET | `/api/course/list` | 否 | 课程列表 |
| GET | `/api/course/{slug}` | 否 | 课程详情（含模块课时树） |
| GET | `/api/modules` | 否 | 模块列表 |
| GET | `/api/lesson/{slug}` | 否 | 课时详情（代码片段/知识点/上下节） |
| GET | `/api/qa/list` | 否 | 题库 |
| GET | `/api/search?q=` | 否 | 全文搜索，返回 `<mark>` 高亮摘要 |
| GET | `/api/search/suggest?q=` | 否 | 搜索建议 |
| GET | `/api/ai/agent` | 否 | 鲸鲸形象配置（表情映射、打招呼语） |
| POST | `/api/ai/ask` | 是 | 向鲸鲸提问，返回回答 + 引用课时 + 生效通道 |
| GET | `/api/ai/health` | 是 | 通道诊断：当前 provider / 是否配了 Key / 降级说明 |
| GET | `/api/progress/summary` | 是 | 学习总览：总进度 / 完成数 / 收藏数 / 累计分钟 |
| GET | `/api/progress` | 是 | 全部学习进度条目 |
| GET | `/api/progress/marks` | 是 | 已完成与已收藏的课时 id 集合 |
| GET | `/api/progress/lesson/{id}` | 是 | 单个课时的进度 |
| PUT | `/api/progress/lesson/{id}` | 是 | 保存进度（`progressPct` / `lastSeconds`） |
| POST | `/api/progress/lesson/{id}/complete` | 是 | 标记完成/未完成 |
| POST | `/api/progress/lesson/{id}/favorite` | 是 | 收藏/取消收藏（切换） |

### 认证

自实现 HMAC-SHA256 会话令牌（零外部依赖），载荷
`userId|username|role|issuedAt|expireAt|nonce`，默认 12 小时有效。
校验用 `MessageDigest.isEqual` 防时序攻击，会话同时落`user_session` 表便于审计与主动登出。
口令用 PBKDF2-HMAC-SHA256（12 万轮 + 16 字节随机盐），格式
`pbkdf2$<iter>$<saltB64>$<hashB64>`。

### 大模型接入

三层可降级的调用链，`application.yml` 里 `app.ai.provider` 决定策略：

| 档 | provider | 鉴权 | 延迟 | 成本 |
| --- | --- | --- | --- | --- |
| 1 | `openai` | `Authorization: Bearer $AI_API_KEY` | 1~4s | 各厂免费额度内多为 0 元 |
| 2 | `ollama` | 占位符（Ollama 不校验） | 0.5~10s | 0 |
| 3 | `local` | 无 | ~45ms | 0 |

`auto`（默认）按 `fallback-order` 逐档尝试，首个成功即返回；全失败则落到 `local` 检索式回答。
**任何一档失败都不会让用户看到报错。**

**为什么所有厂商都走同一份代码**：DeepSeek / 通义千问 / 智谱 / 豆包 / 硅基流动 / vLLM / Ollama
全部是 OpenAI 兼容协议，换厂商只需改 `AI_BASE_URL` + `AI_MODEL`，**代码零改动**。

```yaml
app:
  ai:
    provider: auto              # auto | openai | ollama | local
    base-url: ${AI_BASE_URL:https://api.deepseek.com}
    api-key: ${AI_API_KEY:}
    model: ${AI_MODEL:deepseek-v3}
    fallback-order: ${AI_FALLBACK_ORDER:openai,ollama,local}
    ollama-base-url: ${AI_OLLAMA_BASE_URL:http://127.0.0.1:11434}
    ollama-model: ${AI_OLLAMA_MODEL:qwen2.5:7b}
    timeout-ms: ${AI_TIMEOUT_MS:20000}
    context-limit: 6
```

启用云端模型只需设一个环境变量：

```bash
export AI_API_KEY=sk-xxxxxxxx
export AI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode   # 或其它厂商
export AI_MODEL=qwen3.5-plus
```

**不配任何东西也能跑**：自动跳过 openai 档（无 Key）→ 试 ollama（没装则跳过）→ 落到
`local` 检索式回答，功能完全可用。回答里会带 `provider` / `degraded` 字段，
前端气泡上明写「大模型」或「本地兜底」标签。

详细方案（鉴权流程、延迟实测、成本测算、四级兜底）见
[`docs/pet-and-ai-guide.md`](docs/pet-and-ai-guide.md)。

---

## 前端

Vue 3.5 + TypeScript + Vite 5 + Pinia + vue-router 4。

```
frontend/src/
├── api/          http.ts（拦截器+令牌）、index.ts（类型化接口）
├── stores/       auth.ts（登录态）、agent.ts（鲸鲸对话与表情）、
│                 progress.ts（学习进度与收藏）、pet.ts（桌宠状态机）
├── components/   AgentDrawer.vue（助教抽屉）、FloatingPet.vue（悬浮桌宠）、
│                 GlobalSearch.vue
├── views/        Login / Home / Course / Lesson / Search / Qa
└── styles/       design-system.css（卡通设计系统）
```

### 视觉风格

辨识度锚点是**硬边偏移阴影 + 粗描边**，所有卡片/按钮都是贴纸质感：

- 描边 `3px` 深墨蓝 `#2d3561`，阴影 `3px/5px/8px 0` 同色硬偏移（无模糊）
- 糖果色板：薄荷 `#4ecdc4`、珊瑚 `#ff6b6b`、阳光 `#ffd93d`、丁香 `#a78bfa`
- 圆角 12–36px 全圆角胶囊按钮
- 动效：`pop-in` 弹入、`float-y` 漂浮、`wiggle` 摇摆、`shake` 抖动报错
- 背景：4 层 radial-gradient 手绘圆点纹理

### 鲸鲸 AI 助教

**两个入口**，功能互补：

| 入口 | 形态 | 适合 |
|---|---|---|
| 悬浮桌宠 | 右下角浮层，156px（移动端 116px），可拖拽 | 随手一问 |
| 助教抽屉 | 右上角按钮唤出，全宽面板 | 长问题、看引用 |

桌宠（`components/FloatingPet.vue`）是本项目的重点特性：

- **始终在最上层** —— `position:fixed` + `z-index:9999`，盖住导航/抽屉/悬浮球
- **拖拽移动** —— Pointer Events 统一鼠标与触摸；松手有惯性滑动 + 边界回弹；位置存 localStorage
- **状态动画** —— 待机 / 思考 / 说话 / 拖拽 / 雀跃 五态切换
- **点击唤出气泡** —— 单击直接提问，Enter 发送
- **引用可跳转** —— 回答里的课时链接直达课程页

形象与动画素材取自 `D:\dsh-pet`，webm 视频渲染 + A/B 双缓冲换源机制完整复刻
（详见 [`docs/dsh-pet-analysis.md`](docs/dsh-pet-analysis.md)）。
素材从 106 个 / 53MB 裁剪到 **5 个 / 2.3MB**，首屏只预载待机动画（473KB），
其余状态首次切换时才加载。静态表情图另存于 `frontend/public/assets/agent/`。

素材需要预处理（裁掉左右透明边，否则角色只占画面 33%，在小容器里几乎看不见）：

```bash
bash scripts/prep_pet_assets.sh          # 自动找 ffmpeg
bash scripts/prep_pet_assets.sh <ffmpeg路径>
```

裁切后角色在 156px 容器里占满约 130px，视觉大小提升近 3 倍，总体积基本不变。

### 端到端验证

```bash
python scripts/verify_pet.py          # 桌面端 16 项：置顶/拖拽/气泡/提问/持久化/无报错
python scripts/verify_pet_mobile.py   # 移动端 10 项：缩放/贴底气泡/触摸拖拽/边界约束
```

脚本用 Playwright 驱动真实 Chromium，需要先 `pip install playwright && playwright install chromium`。

---

## 已知限制

1. **ima 知识库未接入** —— 缺凭证。目前课程内容来自 `seed.sql`，等拿到凭证后
   可通过 `generation_log` 表驱动自动生成网页内容与表结构。
2. **无 `vector` 扩展** —— 语义检索尚未实现，当前是关键词检索 + 应用层分词。
   接入 embedding 时建议存`float4[]` 并在应用层算余弦。
3. **`zhparser` 不可用** —— 若后续拿到 superuser 权限，可装上做更准的中文分词。
4. **桌宠不能拖出浏览器窗口** —— 浏览器安全边界，`position:fixed` 只能约束在视口内。
   真正的跨窗口桌宠需要 Electron 壳（dsh-pet 的方案）。
5. **未配置 Key 时 AI 回答偏机械** —— 走 `local` 检索式兜底，能给出正确课时代码片段与
   跳转链接，但没有自由推理与多轮问答能力。可在“AI 接入”页填写账号模型配置，或由站点管理员设置 `AI_API_KEY` 全站默认模型。


