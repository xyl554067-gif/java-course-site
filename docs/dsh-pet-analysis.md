# dsh-pet 项目分析报告

> 分析对象：`D:\dsh-pet`
> 目的：评估把「桌宠」能力移植到 Java 课程网站（浏览器环境）的可行性，并给出改造点。
> 结论先行：**技术路径完全可行，但需要把「桌面应用」范式改写为「Web 页面内浮层」范式。**

---

## 一、目录结构

```
D:\dsh-pet\
├── API.md              # 对外 HTTP API 说明（7340 端口）
├── CORDIS.md           # Cordis 插件宿主接入文档
├── openapi.yaml        # 138KB OpenAPI 契约
├── README.md           # 48KB 完整项目文档
├── assets/             # 宿主侧默认素材
├── data/               # 运行期数据
├── prompts/            # 提示词模板（含「桌面宠物 10 秒动作提示词」）
├── scripts/
├── tools/
└── dsh-pet/            # ★ 插件本体（npm 包）
    ├── src/
    │   ├── client/     # 浏览器半侧（React）
    │   │   ├── app.ts
    │   │   ├── bubble.ts        # 对话气泡
    │   │   ├── command-faces.ts
    │   │   ├── nav-icon.ts
    │   │   ├── notify.ts
    │   │   ├── pet.ts           # ★ 桌宠核心渲染（2404 行）
    │   │   ├── pose.ts
    │   │   ├── progress.ts
    │   │   └── settings.ts
    │   ├── host/       # Electron 宿主半侧
    │   │   ├── anim.ts          # ★ 动画决策层（189 行）
    │   │   ├── chat.ts
    │   │   ├── config.ts
    │   │   ├── llm-call.ts
    │   │   ├── model-selection.ts
    │   │   ├── pose.ts
    │   │   ├── state.ts
    │   │   ├── surface.ts
    │   │   ├── work-status.ts
    │   │   └── topmost-watchdog.test.ts
    │   ├── shared/     # 双侧共享的常量与类型
    │   └── standalone/ # 独立模式
    ├── assets/
    │   ├── webm/       # ★ 动画素材（106 个文件，共 53MB）
    │   ├── pic/        # 光标 / 通知图标
    │   ├── memes/      # 表情包（27 张）
    │   ├── fonts/
    │   ├── config.jsonc  # ★ 动作配置（326 行）
    │   └── logo.png
    ├── lib/
    │   ├── index.js       # Cordis 插件宿主半侧入口
    │   └── client.js      # 浏览器半侧入口（exports['./client']）
    └── runtime/electron-helper/
```

---

## 二、渲染技术：不是 Live2D，是 webm 视频

这是移植评估里最关键的一条。

| 技术方案 | dsh-pet 是否使用 | 说明 |
|---|---|---|
| Live2D | ❌ | 无 Cubism 运行时、无 moc3/physics3json |
| 序列帧 Sprite | ❌ | 无 PNG 序列、无图集 |
| **webm 视频（VP9-alpha）** | ✅ | `assets/webm/` 下 106 个 `.webm` 文件，带 alpha 通道 |
| CSS 动画 | ⚠️ 辅助 | 只用于光标样式、淡入淡出等外围效果 |

### 素材清单（节选）

```
待机呼吸休闲.webm        427KB    ← 待机
工作状态-思考冒泡.webm    409KB    ← 思考
工作状态-忙碌点按.webm    476KB    ← 工作中
工作状态-雀跃庆祝.webm    488KB    ← 成功
深度思考碎碎念.webm      433KB    ← 说话
被鼠标拖拽悬空反馈.webm  465KB    ← 拖拽
点击回应-开心跃动.webm    538KB    ← 点击回应
东张西望.webm            427KB    ← 转向
```

**结论：单动作约 400~500KB，是「质量/体积」权衡后的产物。**
比 Live2D 资源大，但比序列帧小得多，且色彩与原素材完全一致、无需额外解码器。

### 动画切换机制：A/B 双缓冲

dsh-pet 在 `src/client/pet.ts` 里用**两个 `<video>` 元素**交替承载：

```ts
const videoARef = useRef<HTMLVideoElement | null>(null);
const videoBRef = useRef<HTMLVideoElement | null>(null);
// frontRef.current 指向当前显示的那一个
const front = frontRef.current === 0 ? videoARef : videoBRef;
const target = frontRef.current === 0 ? videoBRef : videoARef;
```

流程：**新动画装到后台 video → 播放就绪 → 淡入 → 前台退场**。
直接改同一个 video 的 `src` 会闪黑，在桌宠这种小尺寸下极其刺眼——这是必须复刻的机制。

配套 CSS（`.dsh-pet-video`）：

```css
.dsh-pet-video {
  position:absolute; inset:0; width:100%; height:100%;
  object-fit:contain; pointer-events:none;
  opacity:0; transition:opacity .18s ease; transform-origin:center;
}
.dsh-pet-video.is-front { opacity:1; }
```

**素材加载走 `fetch` + blob URL**，不是直接给 video 挂 src。原因是绕开 video 流式加载在 DSH WebServer 上偶发的失败，同时便于做缓存失效（同名文件替换后不会一直看到旧动画）。

### 朝向处理

`scaleX(-1)` 做左右镜像，`facingRef` 记录 `left | right`：

```ts
el.style.transform = facingRef.current === 'right' ? 'scaleX(-1)' : '';
```

---

## 三、配置体系（`assets/config.jsonc`）

三层归属，改配置前必须知道字段属于哪一层：

| 层级 | 文件 | 字段 |
|---|---|---|
| 实例级 | `pets[]` 每项 | `name / id / size / balanceEnabled / whisperEnabled / workStatusEnabled / fixedEnabled / display / position` |
| 全局默认 | `config.jsonc` 顶层 | `physics / font / confineToScreen / chatMemoryRounds / whisperModel / chatModel / eventsRefreshSec` |
| 条目级 | 每个宠物种类一份 | `whisperPrompt / memes / workStatusTexts / animations / animationWeights` |

### 动作池结构

```jsonc
"animations": {
  "idle":   ["待机呼吸休闲"],
  "turn":   ["东张西望"],
  "drag":   ["被鼠标拖拽悬空反馈"],
  "clicks": ["点击回应-开心跃动", "点击回应-害羞惊讶", "..."],
  "moves": {
    "default": { "minDist": 60, "maxDist": 240, "margin": 20, "leadSec": 2, "tailSec": 2 },
    "actions": [ { "name": "螃蟹走路" }, { "name": "原地漂浮踏步" } ]
  },
  "categories": [            // 随机动作分类池
    { "id": "小动作", "weight": 20, "actions": ["悠闲哼歌", "超大伸懒腰", "..."] },
    { "id": "玩耍",   "weight": 20, "actions": ["原地专心玩魔方", "..."] }
  ],
  "events": {               // 事件动画（不进随机链，只由代码显式触发）
    "workStatus": [
      "工作状态-思考冒泡",   // 0 thinking
      "工作状态-忙碌点按",   // 1 working
      "工作状态-清点归档",   // 2 result
      "工作状态-原地踱步张望",// 3 waiting
      "工作状态-雀跃庆祝",   // 4 success
      "工作状态-垂头叹气冒汗"// 5 error
    ]
  }
}
```

**权重机制**：`animationWeights` 里 `idle:10 + turn:5 + move:5 + 分类权重合计 80 = 100`。
宠物开了 `fixedEnabled` 时，turn/move 两档权重按 0 算，份额自然落到「随机小动作」。

### 工作状态档位（这套设计非常值得借鉴）

6 档语义化状态，与 LLM 生命周期严格对应：

| index | 状态 | 触发时机 | 动画 |
|---|---|---|---|
| 0 | thinking | 回合开始 | 工作状态-思考冒泡 |
| 1 | working | 工具调用中 | 工作状态-忙碌点按 |
| 2 | result | 工具完成 | 工作状态-清点归档 |
| 3 | waiting | 等待用户批准 | 工作状态-原地踱步张望 |
| 4 | success | 回合成功 | 工作状态-雀跃庆祝 |
| 5 | error | 回合出错/超上限 | 工作状态-垂头叹气冒汗 |

**这是「AI 助教的情绪反馈」最自然的状态定义**，本项目的桌宠直接沿用了这套语义（裁剪为 5 态）。

---

## 四、关键依赖

### 运行时依赖

```jsonc
"dependencies": {
  "@anthropic-ai/sdk": "0.135.0",   // Anthropic 协议
  "openai": "7.39.0",               // OpenAI 兼容协议
  "zod": "4.6.7",                   // 配置校验
  "@electron/get": "..."             // 下载 Electron 运行时
}
```

### peerDependencies（强绑定宿主）

```jsonc
"peerDependencies": {
  "@deepseek-ai/dsh-*": "...",      // DeepSeek Harness 全家桶
  "react": "^18.2.0",
  "react-dom": "^18.2.0"
}
```

### 架构特征

- **双入口**：`lib/index.js`（Cordis 插件宿主半侧）+ `lib/client.js`（浏览器半侧）
- **独立模式**：`bin.dsh-pet-standalone` → `lib/standalone.js`，可脱离 DSH 单跑桌宠
- **无打包器**：直接用 `lib/*.js` 作为入口，运行时动态加载 `src/**/*.ts`（Cordis 插件机制）

---

## 五、移植可行性评估

### ✅ 可以直接复用的

| 能力 | 复用方式 |
|---|---|
| 动画素材 | 直接拷贝 `.webm` 文件（`assets/webm/` → `frontend/public/pet/`） |
| A/B 双缓冲切换 | 完整复刻 `videoA/videoB + front` 机制（已在 `FloatingPet.vue` 实现） |
| `scaleX(-1)` 镜像 | 保留能力（本项目暂不自动转向） |
| 状态语义 | 沿用 `workStatus` 6 档的设计思想，裁剪为 5 态 |
| `object-fit:contain` + 淡入淡出 | 原样照搬 |
| 拖拽手感 | 借鉴其「指针捕获 + 拖拽轨迹采样估速度」的思路 |

### ⚠️ 必须改造的

| dsh-pet 做法 | 浏览器里的问题 | 本项目的改造 |
|---|---|---|
| **Electron 透明置顶窗** | 浏览器没有「独立窗口」概念，无法跑到标签页外 | 改为 `position:fixed` + `z-index:9999`，只能在**页面视口内**活动 |
| **`setIgnoreMouseEvents` 穿透** | 浏览器无此 API | 改为命中区域只覆盖桌宠本体（`.pet-layer` 设 `pointer-events:none`，子元素恢复） |
| **物理抛掷系统**（重力/恢复系数/地面摩擦/多宠物碰撞） | 收益低、实现重、浏览器里容易误触 | 简化为**惯性滑动 + 边界回弹**（`glide()`），保留一点手感，成本极低 |
| **106 个动作 + 6 个随机分类池 + 权重系统** | 3.6MB 全量素材对首屏太重；随机链在教学场景无意义 | 只取 **5 个与 AI 交互直接相关的动作**（idle/thinking/talking/dragging/happy），并裁掉左右透明边后共 2.3MB |
| **Cordis 插件宿主 + `/dsh-pet-7340/*` HTTP 契约** | 本项目已有 Spring Boot 后端，无需再造一套宿主协议 | 桌宠直接复用本站 `/api/ai/ask`，无独立服务 |
| **React + Cordis 状态机** | 本项目是 Vue 3 | 用 Pinia store 重写（`stores/pet.ts`） |
| **系统级通知 / 托盘 / 剪贴板** | 浏览器受限 | 全部砍掉，不在教学场景的必要范围内 |
| **多桌宠同屏 + 宠物互撞** | 教学网站不需要 | 单只 |
| **碎碎念（whisper）定时调用模型** | 会持续消耗 token，且打扰学习 | 砍掉。改为**用户主动点击才说话** |

### ❌ 无法移植的

- **跨窗口置顶**（浏览器安全边界）
- **拖出浏览器窗口边界**
- **真正的系统级桌宠常驻**（需要 Electron 壳或浏览器扩展）
- **直接访问 DSH 的模型通道**（本项目有自己的后端与鉴权）

---

## 六、本项目的实现取舍

| 需求 | dsh-pet 原方案 | 本项目实现 | 理由 |
|---|---|---|---|
| 始终在最上层 | Electron 透明置顶窗 | `position:fixed; z-index:9999` | 浏览器内可行的上限 |
| 拖拽移动 | 指针捕获 + 物理 | Pointer Events（鼠标/触摸统一）+ 惯性滑动 + 边界约束 + 位置持久化 | Pointer Events 一套代码覆盖两种输入 |
| 待机/说话/思考 | 106 动作池 + 权重随机 | 5 态固定映射 | 状态少而明确，随机链对教学无价值 |
| 点击唤出气泡 | 右键菜单 + 独立聊天窗 | 单击直接唤起对话气泡（`@pointerup` 且位移 < 4px 判定为点击） | 降低使用门槛 |
| 动画换源 | fetch + blob URL | 直接 `src` + A/B 缓冲 | 素材是同源静态文件，无缓存失效需求，省一层复杂度 |

### 素材预处理：裁掉透明边（重要）

dsh-pet 原始素材是 **640×360**，角色只占画面中央 **33%×74%**（实测 alpha bbox ≈
`x:213~426, y:63~330`）。直接用 `object-fit:contain` 渲染，角色在 150px 容器里
只显示约 50px——**小得几乎看不见**。

dsh-pet 本身没这个问题，因为它用的是 **462px 基准宽度**（桌面尺寸），
而浏览器里 462px 太大。

本项目的解法是**离线预处理**：用 ffmpeg 裁掉左右透明边并重编码。

```bash
# 裁切到内容区（240x300，起点 200,45）后缩放到 280x350
ffmpeg -i idle.webm \
  -vf "crop=240:300:200:45,scale=280:350" \
  -c:v libvpx-vp9 -b:v 0 -crf 40 -row-mt 1 -cpu-used 4 -an \
  idle-cut.webm
```

参数选择的理由：

| 参数 | 值 | 理由 |
|---|---|---|
| `crop` | `240:300:200:45` | 覆盖 5 个动作的全部 alpha bbox，留 8~15px 余量防切边 |
| `scale` | `280:350`（4:5） | 裁后比例；容器用 `aspect-ratio: 4/5` 精确匹配 |
| `crf` | `40` | 视觉无损但体积与原片持平（473KB vs 原 441KB） |
| `-an` | — | 去掉音轨（桌宠不需要声音） |

**效果**：角色在 156px 容器里占满约 130px，视觉大小提升近 3 倍。
重编码后总体积 2.3MB，与裁切前的 2.2MB 基本持平——**体积没涨，可用性大幅提升**。

> 如果不想重新编码，也可以纯用 CSS：`transform: scale(3)` 配合
> `transform-origin: center` 放大。但那样容器尺寸与命中区域会不一致，
> 拖拽手感会变差。离线裁切是更干净的做法。| AI 对话 | 走 DSH 的 LLM 通道 | 本站 `/api/ai/ask`，多通道降级 | 见下节 |

---

## 七、AI 接入方案（与 dsh-pet 的对照）

dsh-pet 的模型接入：`@anthropic-ai/sdk` + `openai` 双 SDK + `model-selection.ts` 做服务商/模型选择，
凭据来自 DSH 宿主配置。本项目不依赖任何外部宿主，自建了一条**可降级的三档链**：

| 档 | 通道 | 鉴权 | 典型延迟 | 成本 |
|---|---|---|---|---|
| 1 | `openai` | `Authorization: Bearer $AI_API_KEY` | 1~4s | 各厂免费额度内多为 0 元 |
| 2 | `ollama` | 占位符 `ollama`（Ollama 不校验） | 0.5~10s | 0（本地推理） |
| 3 | `local` | 无 | 48ms（实测） | 0（数据库检索） |

关键设计：

- **单一协议适配层**。DeepSeek / 通义千问 / 智谱 / 豆包 / 硅基流动 / vLLM / Ollama 全部是
  OpenAI 兼容协议，换厂商只需改 `AI_BASE_URL` + `AI_MODEL`，**代码零改动**。
- **硬超时**。`AI_TIMEOUT_MS`（默认 20s）超时即视为该档失败，无限等待是被禁止的。
- **降级不静默**。响应里带 `provider` 与 `degraded` 字段，前端气泡上明写「本地兜底」标签，
  用户永远知道自己拿到的是哪种质量的回答。
- **三级兜底**。后端降级到 `local` 检索式；后端整个不可达时，前端 `offlineReply()` 再兜一层，
  按关键词给出指路式回复（线程/锁/集合/JVM…），保证功能不中断。

实测结果（本机无 Key、无 Ollama 的环境下）：

```
provider=local  degraded=true  latency=41ms
provider=local  degraded=true  latency=48ms
```

指向 mock OpenAI 端点时：

```
provider=openai degraded=false latency=458ms   ← 正常路径
provider=local  degraded=true  latency=41ms    ← 端点不可达，800ms 内完成降级
```

---

## 八、性能与移动端影响

### 性能

| 项 | 数值 | 说明 |
|---|---|---|
| 素材体积 | 2.3MB（5 个动作，裁切后） | dsh-pet 全量是 53MB / 106 个，裁剪后降到 4% |
| 首次加载 | 只预载 `idle.webm`（473KB） | 其余 4 个在状态首次切换时才 `load()` |
| 换源闪烁 | 无 | A/B 双缓冲交叉淡入 180ms |
| 长时运行内存 | 两个 video 常驻 | 每个 webm 解码后约 1~2MB 显存，可接受 |
| 空闲 CPU | 接近 0 | 待机动画是循环播放，视频解码占用极低 |
| 滚动性能 | 无影响 | 桌宠在独立合成层（`transform` 驱动），不触发主线程重排 |

### 移动端适配

| 项 | 桌面 | 移动 |
|---|---|---|
| 桌宠尺寸 | 156px | 116px（`innerWidth < 720` 自动缩小） |
| 气泡定位 | 跟随桌宠（`bottom: 100%+12px`） | `position:fixed` 贴底全宽，不跟随桌宠 |
| 输入方式 | 鼠标 + 触摸（Pointer Events 统一） | 触摸拖拽 + 键盘输入 |
| `touch-action` | `none` | `none`（防止拖拽时页面跟着滚） |
| 减少动效 | 尊重 `prefers-reduced-motion` | 同 |

### 已知取舍

- 桌宠**不能拖出浏览器窗口**——这是浏览器的硬边界。若需要真正的跨窗口桌宠，
  必须回到 Electron 壳（dsh-pet 的方案）。
- 桌面端同时存在「左下角悬浮球」与「右下角桌宠」两个入口，功能有重叠。
  保留两者是因为：悬浮球开的是完整对话抽屉（适合长问题），桌宠是轻量气泡（适合随手一问）。
