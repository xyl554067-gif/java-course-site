# 悬浮式 AI 助教桌宠 —— 使用与配置指南

> 形象来自 `D:\dsh-pet` 的「鲸鲸」（蓝发猫耳 Ciallo 小女仆）。
> 动画素材直接取自 dsh-pet 的 `assets/webm/`，渲染机制（webm + A/B 双缓冲）完整复刻。
> 移植评估详见 [`dsh-pet-analysis.md`](./dsh-pet-analysis.md)。

---

## 一、它能做什么

| 能力 | 说明 |
|---|---|
| 始终在最上层 | `position:fixed` + `z-index:9999`，盖住导航、抽屉、悬浮球 |
| 拖拽移动 | 鼠标拖拽 / 触摸拖拽（Pointer Events 统一），带边界约束与位置持久化 |
| 状态动画 | 待机 `idle` / 思考 `thinking` / 说话 `talking` / 拖拽 `dragging` / 雀跃 `happy` |
| 点击唤出气泡 | 单击（非拖拽）弹出对话气泡，可直接输入提问 |
| 惯性滑动 | 松手后按瞬时速度继续滑行，撞到边界回弹 |
| 引用跳转 | 回答里的课时链接可点击直达对应课程页 |
| 通道标识 | 气泡角标显示「大模型」或「本地兜底」，用户知道答案从哪来 |

---

## 二、配置项

### 2.1 后端（`backend/src/main/resources/application.yml`）

全部通过环境变量注入，**密钥不进代码库**。

| 配置项 | 环境变量 | 默认值 | 说明 |
|---|---|---|---|
| `app.ai.provider` | `AI_PROVIDER` | `auto` | `auto` / `openai` / `ollama` / `local` |
| `app.ai.base-url` | `AI_BASE_URL` | `https://api.deepseek.com` | OpenAI 兼容端点根地址 |
| `app.ai.api-key` | `AI_API_KEY` | 空 | 鉴权 Key，缺失则跳过 openai 档 |
| `app.ai.model` | `AI_MODEL` | `deepseek-v3` | 模型名 |
| `app.ai.fallback-order` | `AI_FALLBACK_ORDER` | `openai,ollama,local` | auto 模式尝试顺序 |
| `app.ai.ollama-base-url` | `AI_OLLAMA_BASE_URL` | `http://127.0.0.1:11434` | 本地模型地址 |
| `app.ai.ollama-model` | `AI_OLLAMA_MODEL` | `qwen2.5:7b` | 本地模型名（需 `ollama pull`） |
| `app.ai.timeout-ms` | `AI_TIMEOUT_MS` | `20000` | 单次调用硬超时 |
| `app.ai.context-limit` | — | `6` | 喂给模型的课程上下文条数 |

### 2.2 前端

桌宠本身**零配置**，全部逻辑内置在 `frontend/src/components/FloatingPet.vue` 与
`frontend/src/stores/pet.ts`。

| 项 | 位置 | 默认值 |
|---|---|---|
| 桌宠尺寸 | `FloatingPet.vue` → `SIZE` | 桌面 156px / 移动 116px |
| 位置持久化 key | `FloatingPet.vue` → `STORAGE_KEY` | `javacourse.pet.pos`（localStorage） |
| 动画映射 | `stores/pet.ts` → `PET_ANIMATIONS` | 见下表 |

### 2.3 动画素材映射

| 状态 | 文件 | 原始素材（dsh-pet） |
|---|---|---|
| `idle` | `/pet/idle.webm` | 待机呼吸休闲 |
| `thinking` | `/pet/thinking.webm` | 工作状态-思考冒泡 |
| `talking` | `/pet/talking.webm` | 深度思考碎碎念 |
| `dragging` | `/pet/dragging.webm` | 被鼠标拖拽悬空反馈 |
| `happy` | `/pet/happy.webm` | 工作状态-雀跃庆祝 |

> 原始文件名是中文，这里改成 ASCII —— 避免各平台文件系统与 HTTP 层的 URL 编码差异
> （实测中文路径在部分客户端会返回 400）。素材本体是原文件，未做任何转码。

---

## 三、启动运行

### 3.1 环境要求

- JDK 17+（开发用 JDK 21 编译，target 17）
- Maven 3.8+
- Node.js 18+（开发用 22）
- KingbaseES V8 实例（默认 `127.0.0.1:54321`，库 `javacourse`）
- **可选**：Ollama（本地模型档）、任意 OpenAI 兼容 API Key（云端档）

### 3.2 启动数据库

KingbaseES 的 License 用全局共享内存（`Global\kingbase:` 内核对象），
创建它需要 `SeCreateGlobalPrivilege`，**非管理员账号无法启停实例**——请手动启动。

```bash
bash scripts/kb_start.sh      # 检查实例状态，未运行则给出启动提示
bash scripts/kb_verify.sh     # 只读校验：各表行数 / 课程结构 / 中文编码
```

### 3.3 启动后端

```bash
cd backend
mvn -o -DskipTests package
java -jar target/javacourse-server-1.0.0.jar --server.port=8080
```

**显式指定 `--server.port`**：环境里若存在 `SERVER_PORT` 变量，Spring Boot 会读到随机端口
（历史上踩过：启动到 57628 然后被占用）。

默认账号密码：`admin` / `123456`、`demo` / `123456`。

### 3.4 启动前端

```bash
cd frontend
npm install --cache ./.npm-cache     # 注意：默认 npm cache 目录不可写，必须指定
npm run dev                          # http://127.0.0.1:5173
```

Vite 已配置把 `/api` 代理到 `127.0.0.1:8080`。

### 3.5 启用大模型

**方式 A：云端 API（推荐）**

```bash
# DeepSeek
export AI_API_KEY=sk-xxxxxxxx
export AI_BASE_URL=https://api.deepseek.com
export AI_MODEL=deepseek-v3
java -jar target/javacourse-server-1.0.0.jar --server.port=8080
```

其他厂商只改 base-url 与 model：

```bash
# 通义千问
export AI_API_KEY=sk-xxxxxxxx
export AI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode
export AI_MODEL=qwen3.5-plus

# 智谱 GLM
export AI_API_KEY=xxxxxxxx
export AI_BASE_URL=https://open.bigmodel.cn/api/paas
export AI_MODEL=glm-4-flash

# 豆包（火山方舟）
export AI_API_KEY=xxxxxxxx
export AI_BASE_URL=https://ark.cn-beijing.volces.com/api/v3
export AI_MODEL=doubao-seed-mini-250615

# 硅基流动
export AI_API_KEY=sk-xxxxxxxx
export AI_BASE_URL=https://api.siliconflow.cn
export AI_MODEL=Qwen/Qwen2.5-7B-Instruct
```

**方式 B：本地模型（零成本、零隐私）**

```bash
ollama pull qwen2.5:7b
ollama serve     # 监听 127.0.0.1:11434
# 不用设 AI_API_KEY，auto 模式会自动跳过 openai 档去试 ollama
```

**方式 C：不配任何东西（默认）**

直接启动即可。`auto` 模式检测到没有 Key 会跳过 openai 档，试 ollama（没装则跳过），
最终落到 `local` 检索式回答——**功能完全可用**，只是措辞更机械、没有自由推理能力。

### 3.6 验证接入状态

```bash
# 登录拿 token
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","password":"123456"}' | python -c "import sys,json;print(json.load(sys.stdin)['data']['token'])")

# 看当前通道
curl -s http://127.0.0.1:8080/api/ai/health -H "Authorization: Bearer $TOKEN"

# 实际提问（会返回 provider / degraded / latencyMs）
curl -s -X POST http://127.0.0.1:8080/api/ai/ask \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"question":"int和long有什么区别"}'
```

---

## 四、鉴权方式

| 通道 | 方式 | 说明 |
|---|---|---|
| `openai` | `Authorization: Bearer $AI_API_KEY` | Key 只从环境变量注入，不入库、不进版本库 |
| `ollama` | `Authorization: Bearer ollama` | Ollama 不校验 Key，但部分网关缺 header 会拒请求，故发占位符 |
| `local` | 无 | 纯数据库检索 |

请求流程（`openai` 档）：

```
浏览器 POST /api/ai/ask  { question }
  → Spring Security 拦截器校验 Bearer token，取 userId
  → CourseRepository.searchContext(整串 + 分词 OR) 捞候选课时
  → hit() 相关度打分排序，取 topN（默认 6 条）
  → 拼 prompt：system=鲸鲸人设 / user=课程资料 + 问题
  → ModelGateway 按 fallback-order 逐档尝试
      ├─ openai 成功 → 直接返回
      ├─ openai 失败 → 记失败原因，试 ollama
      └─ 全失败 → local 检索式回答
  → 落库 ai_chat_session / ai_chat_message
  → 返回 { answer, citations, sessionId, latencyMs, provider, degraded }
```

---

## 五、响应延迟与成本约束

### 延迟实测

| 场景 | provider | degraded | 延迟 |
|---|---|---|---|
| 无 Key、无 Ollama（本机实测） | `local` | `true` | **41 ~ 48 ms** |
| 端点可达（mock 实测，含 400ms 人为 sleep） | `openai` | `false` | **458 ms** |
| 端点不可达（连接被拒） | `local` | `true` | **41 ms**（800ms 内完成整条降级链） |

### 云端档参考延迟（各厂实测区间）

| 厂商/模型 | 典型延迟 | 备注 |
|---|---|---|
| 豆包 Seed-Mini | ~0.9s | 最快，P95 1.6s |
| DeepSeek V4-Flash | ~1.2s | 编程能力最强 |
| 智谱 GLM-4-Flash | ~1.8s | 完全免费额度内 |
| 通义 Qwen3.5-Plus | ~2.1s | 中文语感最好，但 P95 4.2s 偶发超时 |

### 成本

| 档 | 单次成本 | 说明 |
|---|---|---|
| `local` | 0 | 数据库查询 |
| `ollama` | 0 | 本机算力 |
| `openai` | 多数场景 0 元 | 各厂免费额度：通义新用户 7000 万 token、豆包 200 万/天、智谱 500 万/月、DeepSeek 500 万一次性 |

超出免费额度后：DeepSeek V4-Flash 输入 ¥0.18/百万、输出 ¥2.0/百万。
本项目的 prompt 约 1.5~2.5k token（6 条课程上下文 + 人设 + 问题），
单次成本量级在「几分之一厘到几厘」之间。

### 成本控制手段

1. `context-limit` 默认 6 条，不是 42 条全量
2. 每条上下文正文截断到 1200 字符
3. `temperature 0.6` / `max_tokens 1500`
4. 桌宠**不做定时碎碎念**（dsh-pet 的 whisper 每 5 分钟调一次模型），
   只在用户主动提问时才调用——这是本项目省 token 的关键设计决策

---

## 六、降级兜底设计

三级兜底，任何一级失败都不会让用户看到报错：

```
第 1 级：openai（云端大模型）
   ↓ 失败（连接拒绝 / 超时 / 4xx / 响应无 content）
第 2 级：ollama（本地模型）
   ↓ 失败
第 3 级：local（课程检索式，后端内）
   ↓ 后端整体不可达
前端 offlineReply()（关键词指路）
```

### 第 3 级（后端内）输出示例

```
Ciallo～关于「HashMap为什么线程不安全」，我在课程里找到了这些内容：

**1. ConcurrentHashMap 与线程安全**
分段锁到 CAS 的演进。

> 分段锁到 CAS 的演进。

[查看该课时](/lesson/concurrenthashmap)
...
```

它从检索到的课时正文里挑出与问题关键词重合度最高的段落，结构化拼装，并附上跳转链接。

### 第 4 级（前端）输出示例

```
呜哇，鲸鲸的模型线缆暂时松了，先给你指个路喵～

并发这块建议先看「模块 3 · 并发编程」里的线程池与线程状态流转；
提问时可以带上具体的 API 名（比如 ThreadPoolExecutor），我能定位得更准喵～

（网络恢复后我就能直接回答啦）
```

按关键词（线程/锁/集合/JVM/异常/字符串）分流给出指路建议；都不匹配时引导用户用搜索框或课程目录。

---

## 七、页面性能影响

### 体积

| 项 | 数值 | 对比 |
|---|---|---|
| 桌宠素材 | **2.3 MB**（5 个 webm） | dsh-pet 全量 53 MB / 106 个 → 裁剪到 4% |
| 首屏预载 | 仅 `idle.webm` 473 KB | 其余 4 个状态首次切换时才 `load()` |
| 主包 JS | +8.2 KB（gzip +3.7 KB） | `index-*.js` 180.05 KB / gzip 69.92 KB |

### 运行时

| 项 | 影响 |
|---|---|
| 空闲 CPU | 接近 0（循环播放的视频解码占用极低） |
| 内存 | 两个 `<video>` 常驻，各约 1~2 MB 解码显存 |
| 滚动 | **无影响**——桌宠在独立合成层，动画由 `transform` 驱动，不触发主线程重排 |
| 换源闪烁 | **无**——A/B 双缓冲交叉淡入 180ms |

### 渲染层优化点

```css
.pet-body {              /* 动画只用 transform / opacity —— 走合成层，不触发 layout */
  transition: transform .18s cubic-bezier(.34, 1.56, .64, 1);
}
.pet-video { opacity: 0; transition: opacity .18s ease; }
.pet-video.is-front { opacity: 1; }
```

所有状态动效（`pet-pulse` / `pet-bounce` / `pet-pop`）只改 `transform`，
不触碰 `width/height/top/left`，因此不会引起重排。

---

## 八、移动端适配

| 项 | 桌面（≥720px） | 移动（<720px） |
|---|---|---|
| 桌宠尺寸 | 156px | **116px**（自动缩小） |
| 气泡定位 | 跟随桌宠（`bottom: calc(100% + 12px)`） | `position:fixed` 贴底全宽，不跟随桌宠 |
| 气泡宽度 | `min(320px, 100vw-32px)` | `left:12px; right:12px` |
| 气泡高度上限 | `min(420px, 60vh)` | `56vh` |
| 拖拽 | 鼠标 Pointer Events | 触摸 Pointer Events（同一套代码） |
| `touch-action` | `none` | `none`（防拖拽时页面跟着滚） |
| 阴影 | `drop-shadow(0 6px 10px)` | `drop-shadow(0 4px 8px)`（更轻） |
| 消息气泡宽度 | `max-width: 88%` | `max-width: 92%` |
| 减少动效 | 尊重 `prefers-reduced-motion: reduce` | 同 |

### 移动端已知限制

1. **桌宠不能拖出视口**——边界约束在 `bounds()` 里强制生效。
2. **软键盘弹出会遮挡底部**：桌宠默认位置在右下角，键盘弹出时可能被盖住。
   缓解：气泡是 `fixed` 贴底，键盘弹出会把视口高度压缩，此时气泡仍在可视区内。
3. **iOS Safari 的自动播放策略**：`muted` 属性已加，正常可自动播放；
   首次用户交互时才切换的视频也会尝试 `play()` 并在失败时静音重试。

---

## 九、接口清单

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/api/ai/agent` | 是 | 助教形象元信息（前端渲染表情包用） |
| POST | `/api/ai/ask` | 是 | 提问。返回 `{answer, citations, sessionId, latencyMs, agent, provider, degraded}` |
| GET | `/api/ai/health` | 是 | 通道诊断：当前 provider / 是否配了 Key / 降级说明 |

---

## 十、常见问题

**Q：桌宠不出现？**
A：桌宠只在非登录页渲染（`v-if="!bare"`）。确认已登录，且没有在 `/login` 路由。

**Q：桌宠是黑的 / 不透明？**
A：webm 的 alpha 通道需要浏览器支持 VP9 alpha。检查浏览器版本；
Edge/Chrome 90+ 均支持。素材本体是原文件，未转码。

**Q：拖不动？**
A：先登录——未登录时点击会跳登录页。已登录时按住桌宠拖动即可。

**Q：气泡说"本地兜底"？**
A：说明云端与本地模型都不可用。查 `GET /api/ai/health` 看 `openaiConfigured` 与 `note`。
最常见原因是没设 `AI_API_KEY`（或设了但 Key 无效）。

**Q：想只测本地模型？**
A：`export AI_PROVIDER=ollama AI_OLLAMA_MODEL=qwen2.5:7b`，
并确保 `ollama serve` 已在运行、`ollama list` 里能看到该模型。
