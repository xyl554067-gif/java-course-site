# 前端参考

根目录 `frontend/`，构建工具 Vite 5，Vue 3.5 `<script setup>` + TypeScript 5.6，状态管理 Pinia 2，路由 vue-router 4（**hash 模式**）。

## 目录

```
src/
├── main.ts                # 应用入口
├── App.vue                # 布局骨架 + <FloatingPet> + <GlobalSearch> + <AgentDrawer>
├── api/
│   ├── http.ts             # axios 实例，统一 Authorization 头与错误提示
│   └── index.ts           # 类型化 API 封装（authApi / courseApi / searchApi / aiApi / progressApi）
├── components/
│   ├── FloatingPet.vue     # 悬浮 AI 助教桌宠
│   ├── GlobalSearch.vue    # 全局搜索
│   └── AgentDrawer.vue     # 侧边 AI 助教抽屉
├── router/index.ts         # 路由 + 登录守卫
├── stores/
│   ├── auth.ts             # 登录态、令牌持久化
│   ├── progress.ts         # 学习进度、收藏
│   ├── pet.ts              # 桌宠状态机、动画映射、本地兜底回复
│   └── agent.ts            # 抽屉式助教会话
├── styles/design-system.css# 设计令牌（颜色/描边/阴影/圆角/字体/布局）
└── views/
    ├── LoginView.vue       # 登录（meta.public + bare）
    ├── HomeView.vue        # 首页
    ├── CourseView.vue      # 课程详情
    ├── LessonView.vue      # 课时阅读
    ├── SearchView.vue      # 搜索结果
    └── QaView.vue          # 题库
```

## 路由与守卫

| path | name | 说明 |
|---|---|---|
| `/login` | `login` | `meta: { public: true, bare: true }`——bare 布局不渲染桌宠 |
| `/` | `home` | 首页 |
| `/course/:slug` | `course` | 课程详情 |
| `/lesson/:slug` | `lesson` | 课时阅读 |
| `/search` | `search` | 搜索结果 |
| `/qa` | `qa` | 题库 |

`router.beforeEach`：非 public 路由未登录 → 重定向 `/login` 并带 `redirect` query；已登录访问 `/login` → 回首页。

## 状态要点

**auth.ts** — 令牌存 `localStorage`，`isLogged` 派生；登出清空并跳登录页。

**progress.ts** — `ProgressSummary` / `ProgressItem` / `FavoriteItem`；`useProgressStore` 暴露 `summary`、`items`、`favorites`、`loadAll()`、`saveProgress(lessonId, pct, seconds)`、`toggleFavorite(lessonId)`。

**pet.ts** — 核心类型：
```ts
type PetState = 'idle' | 'thinking' | 'talking' | 'dragging' | 'happy'
export const PET_ANIMATIONS: Record<PetState, string> = {
  idle: '/pet/idle.webm',
  thinking: '/pet/thinking.webm',
  talking: '/pet/talking.webm',
  dragging: '/pet/dragging.webm',
  happy: '/pet/happy.webm',
}
```
`ask()` 捕获异常时调本地 `offlineReply(q)`（按线程/锁/集合/JVM/字符串/异常 6 组正则分流给指路建议），保证离线可用。`provider` 与 `degraded` 字段驱动气泡上的通道徽标。

## 桌宠组件要点（FloatingPet.vue）

- 根层 `.pet-layer`：`position: fixed; z-index: 9999; pointer-events: none`（只有内部元素可交互）。
- 两个 `<video>`（`videoA` / `videoB`）做 A/B 双缓冲，`.is-front` 控制 `opacity`，`transition: opacity .18s`。
- `switchAnimation(src)`：新动画装到后台 video → `play()` → 成功后切 `front` 标记并把旧前台淡出。
- 尺寸：桌面 156px，移动端 116px；`HEIGHT_RATIO = 5/4`，`aspect-ratio: 4/5`。
- 边界 `bounds()`：`minY = 78`（避开顶部导航），其余按视口减尺寸与 padding。
- 拖拽用 **Pointer Events**（`pointerdown/move/up` + `setPointerCapture`），位移 > 4px 判为拖拽，否则判为点击唤出气泡。松手后 `glide()` 惯性滑动，衰减 0.94，撞边界回弹。
- `computeBubbleDir()`：桌宠位于页面上半部且上方空间不足时，气泡加 `.pet-bubble--down` 改为向下展开。
- 位置持久化在 `localStorage`。
- `@media (max-width: 720px)` 缩小尺寸与气泡宽度；`prefers-reduced-motion` 降低动效。

**素材文件名必须 ASCII** —— 中文名在部分客户端会返回 400。原始 webm 四周留白多，需用 `scripts/prep_pet_assets.sh`（ffmpeg `crop=240:300:200:45,scale=280:350` + `libvpx-vp9 -crf 40`）离线裁切。

## 设计系统

`frontend/src/styles/design-system.css` 的 CSS 变量是唯一视觉来源：

| 组 | 变量 |
|---|---|
| 糖果色板 | `--c-mint` `--c-coral` `--c-sun` `--c-lilac` `--c-peach` `--c-sky` `--c-grape` 及 `*-deep` |
| 描边/文字 | `--c-ink: #2d3561` `--c-ink-soft` `--c-ink-faint` |
| 背景 | `--c-cream: #fffaf3` `--c-cream-deep` `--c-paper` |
| 描边宽度 | `--bw-thin: 2px` `--bw-base: 3px` `--bw-thick: 4px` |
| 圆角 | `--radius-sm/md/lg/xl/full` |
| 硬边阴影 | `--shadow-sm: 3px 3px 0 var(--c-line)` `--shadow-md: 5px 5px 0` `--shadow-lg: 8px 8px 0` |
| 字体 | `--font-round`（标题）`--font-body`（正文）`--font-mono`（代码） |
| 布局 | `--nav-h: 68px` `--container: 1240px` |

风格要点：3px 深墨蓝描边 + 硬边偏移投影（无模糊）+ 糖果色块 + 弹跳动效。新组件一律用变量，不写死色值与圆角。

## API 封装

`api/http.ts` 建 axios 实例（baseURL `/api`），请求拦截器注入 `Authorization`，响应统一解包 `ApiResponse` 并在失败时抛错。`api/index.ts` 按域分组：`authApi` / `courseApi` / `searchApi` / `aiApi` / `progressApi`（`summary` `list` `marks` `lesson/{id}` `PUT lesson/{id}` `POST lesson/{id}/complete` `POST lesson/{id}/favorite`）。`AskResult` 含 `provider?: string` 与 `degraded?: boolean`。
