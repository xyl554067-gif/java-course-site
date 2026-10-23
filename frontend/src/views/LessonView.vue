<script setup lang="ts">

// 静态资源基址：GitHub Pages 子路径部署时用 BASE_URL 拼接，避免绝对路径 404
const ASSET_BASE = import.meta.env.BASE_URL || '/'
import { ref, watch, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import hljs from 'highlight.js/lib/common'
import 'highlight.js/styles/github.css'
import { courseApi, codeApi } from '@/api'
import { errMsg, getToken, API_BASE_URL } from '@/api/http'
import { useAgentStore } from '@/stores/agent'
import { useProgressStore } from '@/stores/progress'

const route = useRoute()
const router = useRouter()
const agent = useAgentStore()
const progress = useProgressStore()

const lesson = ref<any>(null)
const snippets = ref<any[]>([])
const knowledge = ref<any[]>([])
const prev = ref<any>(null)
const next = ref<any>(null)
const loading = ref(true)
const error = ref('')
const saving = ref(false)

const lessonId = computed(() => lesson.value?.id as number | undefined)
const isFavorite = computed(() => (lessonId.value ? progress.isFavorite(lessonId.value) : false))
const isCompleted = computed(() => (lessonId.value ? progress.isCompleted(lessonId.value) : false))
const savedPct = computed(() => {
  const p = lessonId.value ? progress.progressOf(lessonId.value) : null
  return p?.progressPct ?? 0
})
/** 当前课时的「我学了」次数（按用户维度统计，不再用全站浏览量冒充） */
const lessonStudyCount = computed(() => {
  const p = lessonId.value ? progress.progressOf(lessonId.value) : null
  return p?.studyCount ?? 0
})
/** 当前课时的累计有效学习秒数 */
const lessonStudySeconds = computed(() => {
  const p = lessonId.value ? progress.progressOf(lessonId.value) : null
  return p?.totalSeconds ?? 0
})
const lessonStudyMinutes = computed(() => Math.floor(lessonStudySeconds.value / 60))

/** 滚动进度：按已读位置估算百分比，节流上报 */
let ticking = false
function onScroll() {
  if (ticking || !lessonId.value) return
  ticking = true
  requestAnimationFrame(() => {
    ticking = false
    const doc = document.documentElement
    const total = doc.scrollHeight - doc.clientHeight
    const pct = total <= 0 ? 100 : Math.min(100, Math.round((doc.scrollTop / total) * 100))
    if (pct > savedPct.value) void reportProgress(pct)
  })
}

// ------------------------------------------------------------------
// 真实学习计时
//
// 之前的实现是用「滚动百分比 × 课时时长」推算学习时长，既不真实也无法在
// 刷新/切课后恢复。这里改为真实计时：
//   * 每秒累加，但页面不可见（切到别的标签页）时暂停，避免"挂着不动也算时长"
//   * 每 30 秒心跳上报一次「本次会话累计秒数 + 本次新增秒数」
//   * 切课/离开页面时立即结算并清零计时器，避免计时器泄漏与重复累加
//   * 刷新页面 / 课时间来回切换时复用同一把会话标识（带存活窗口），学习次数不会重复计
// ------------------------------------------------------------------

/** 会话标识：同一课时的一次连续学习共用一个 key（单槽，存当前正在学的课时） */
const SESSION_KEY = 'javacourse.study.session'
/** 心跳间隔（毫秒） */
const HEARTBEAT_MS = 30_000
/** 会话存活窗口（毫秒）：窗口内视为同一次学习，超时后再进来才计新的一次 */
const SESSION_TTL_MS = 2 * 60 * 60 * 1000

/** 本次会话已学秒数（当前课时） */
let sessionSeconds = 0
/** 各课时上次上报已计入的秒数，用于算出增量（切课时各自的增量不能混） */
const reported = new Map<number, number>()
/** 待上报队列：请求在途时新产生的上报先排队，避免被丢弃 */
const pending: { lessonId: number; pct: number; seconds: number; sessionKey: string }[] = []
/** 当前会话标识 */
let sessionKey = ''
/** 计时器 */
let timerId = 0
/** 心跳定时器 */
let heartbeatId = 0
/** 是否已结算（防止重复结算） */
let settled = false

/** 当前滚动进度百分比（心跳上报时一起带上） */
function currentPct(): number {
  const doc = document.documentElement
  const total = doc.scrollHeight - doc.clientHeight
  if (total <= 0) return 100
  return Math.min(100, Math.round((doc.scrollTop / total) * 100))
}

/**
 * 取（并锁定）当前课时的会话标识。
 * 标识按「当前正在学的课时」单槽存放：只要还在学的还是这个课时、且没超出存活窗口，
 * 就复用同一把 key —— 刷新页面、来回切换路由都不会被算成新的一次学习；
 * 换成另一个课时（或超时后再回来）才生成新 key，计为新的一次学习。
 * 注意：不能靠「卸载时删除 key」来做这件事 —— 刷新页面同样会卸载组件，
 * 一旦删掉，刷新就会被误判成新的一次学习。
 */
function ensureSessionKey(id: number): { key: string; seconds: number; reportedSeconds: number } {
  let cur: { lessonId: number; key: string; born: number; seconds?: number; reportedSeconds?: number } | null = null
  try {
    cur = JSON.parse(sessionStorage.getItem(SESSION_KEY) || 'null')
  } catch {
    cur = null
  }
  if (cur && cur.lessonId === id && Date.now() - cur.born <= SESSION_TTL_MS) {
    return { key: cur.key, seconds: cur.seconds ?? 0, reportedSeconds: cur.reportedSeconds ?? 0 }
  }
  const key = `${id}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
  sessionStorage.setItem(SESSION_KEY, JSON.stringify({ lessonId: id, key, born: Date.now(), seconds: 0, reportedSeconds: 0 }))
  return { key, seconds: 0, reportedSeconds: 0 }
}

function persistSessionClock() {
  try {
    const cur = JSON.parse(sessionStorage.getItem(SESSION_KEY) || 'null')
    if (cur?.key === sessionKey) {
      cur.seconds = sessionSeconds
      cur.reportedSeconds = reported.get(lessonId.value ?? -1) ?? 0
      sessionStorage.setItem(SESSION_KEY, JSON.stringify(cur))
    }
  } catch { /* storage may be disabled; server reporting still works */ }
}

/**
 * 上报一次进度与时长。
 *
 * 切课时会并发触发两次上报：旧课时的结算（stopTimer）与新课时的首次上报（startTimer）。
 * 若请求在途时直接把新调用丢掉，新课时的会话标识就迟迟不落库，
 * 要等到下一次上报才补上 —— 表现为「刷新一次学习次数 +1」的延迟重复计数。
 * 因此这里把待上报的请求排队，等当前请求结束后按序补发。
 */
async function reportProgress(pct: number) {
  if (!lessonId.value) return
  // 排队时必须连课时 id 一起记下：等轮到它时 lessonId 可能已经切到别的课时
  pending.push({ lessonId: lessonId.value, pct, seconds: sessionSeconds, sessionKey })
  if (saving.value) return
  saving.value = true
  try {
    while (pending.length) {
      const job = pending.shift()!
      const delta = Math.max(0, job.seconds - (reported.get(job.lessonId) ?? 0))
      await progress.save(job.lessonId, job.pct, job.seconds, delta, job.sessionKey)
      reported.set(job.lessonId, job.seconds)
      persistSessionClock()
    }
  } catch {
    // 上报失败不打断阅读；下次心跳会带上未结算的增量
  } finally {
    saving.value = false
  }
}

/** 结算并停止计时（切课、离开页面、页面隐藏时调用） */
function stopTimer(flush = true) {
  if (timerId) {
    clearInterval(timerId)
    timerId = 0
  }
  if (heartbeatId) {
    clearInterval(heartbeatId)
    heartbeatId = 0
  }
  if (!flush || settled || !lessonId.value) return
  settled = true
  void reportProgress(currentPct())
}

/** 启动计时 */
function startTimer(id: number) {
  stopTimer(false)
  settled = false
  const savedSession = ensureSessionKey(id)
  sessionSeconds = savedSession.seconds
  reported.set(id, savedSession.reportedSeconds)
  sessionKey = savedSession.key
  startTicking()
  // 进入课时立即上报一次：把「本次学习」这件事马上落到库里，
  // 否则学习次数要等到滚动或 30 秒心跳之后才入库，统计口径不可靠
  void reportProgress(currentPct())
}

/** 只负责跑秒表与心跳，不重置已累计的秒数（页面隐藏→可见时用它恢复） */
function startTicking() {
  if (timerId) return
  // 页面可见才计时：切到别的标签页/最小化时暂停
  timerId = window.setInterval(() => {
    if (document.visibilityState === 'visible') {
      sessionSeconds += 1
      persistSessionClock()
    }
  }, 1000)
  if (!heartbeatId) {
    heartbeatId = window.setInterval(() => {
      if (document.visibilityState !== 'visible') return
      void reportProgress(currentPct())
    }, HEARTBEAT_MS)
  }
}

/** 标签页隐藏：结算已学时长并暂停秒表 */
function onVisibilityChange() {
  if (document.visibilityState === 'hidden') {
    stopTimer(true)
  } else {
    // 回到前台：隐藏时已结算当前区间，重新允许结算并接着计时。
    // 若不清掉 settled，页面再次可见后虽然能计时，后续离开却不会保存。
    if (lessonId.value) {
      settled = false
      startTicking()
    }
  }
}

/**
 * 页面关闭/刷新：用 keepalive 请求把最后的时长结算掉。
 * 不用 sendBeacon 是因为接口鉴权走 Authorization 头，sendBeacon 不支持自定义头。
 *
 * 这里不能因为 settled 已经为true 就跳过：刷新时 onUnmounted 会先跑并置 settled，
 * 若因此跳过，本次会话的最后一段时长与进度就永远不会入库。
 * 同一 sessionKey 重复上报是幂等的（后端按 key 去重），多发一次没有副作用。
 */
function onPageHide() {
  if (!lessonId.value) return
  settled = true
  const id = lessonId.value
  const pct = currentPct()
  const delta = Math.max(0, sessionSeconds - (reported.get(id) ?? 0))
  // 用本次会话自己的 key，而不是可能已被别处更新的全局变量
  const key = sessionKey
  void fetch(`${API_BASE_URL}/progress/lesson/${id}`, {
    method: 'PUT',
    keepalive: true,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${getToken()}`,
    },
    body: JSON.stringify({
      progressPct: pct,
      lastSeconds: sessionSeconds,
      deltaSeconds: delta,
      sessionKey: key,
    }),
  }).catch(() => {
    /* 页面正在卸载，请求失败也无法处理，忽略 */
  })
}

function toggleFav() {
  if (lessonId.value) void progress.toggleFavorite(lessonId.value)
}

async function toggleDone() {
  if (lessonId.value) await progress.markCompleted(lessonId.value, !isCompleted.value)
}

/** 把 Markdown 正文渲染成 HTML：标题、列表、代码块、表格 */
function renderMarkdown(src: string): string {
  const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  const blocks: string[] = []
  // 换行统一为 \n：课程正文在库里是 CRLF，不归一会让下面的围栏正则匹配不到
  const normalized = String(src || '').replace(/\r\n?/g, '\n')
  // 先摘出代码块，避免被行内规则破坏；此处只留占位标识，代码块 HTML 在逐行渲染完成后回填
  const text = normalized.replace(/```(\w*)\n([\s\S]*?)```/g, (_m, lang, code) => {
    // 只去掉结尾那个换行（它是闭合围栏的分隔符），其余缩进与空行原样保留
    const raw = String(code).replace(/\n$/, '')
    let html: string
    try {
      html = hljs.highlight(raw, { language: lang || 'java' }).value
    } catch {
      html = esc(raw)
    }
    // class="hljs" 让 highlight.js 主题的基础前景色/背景色生效
    blocks.push(`<pre class="md-code"><code class="hljs">${html}</code></pre>`)
    return `%%BLOCK${blocks.length - 1}%%`
  })

  const lines = esc(text).split('\n')
  const out: string[] = []
  let inList: 'ul' | 'ol' | null = null

  const closeList = () => {
    if (inList) {
      out.push(`</${inList}>`)
      inList = null
    }
  }

  /** 表格分隔行，形如 | --- | :---: | */
  const isTableSep = (l: string) => /^\|[\s:|-]+\|?$/.test(l.trim()) && l.includes('-')
  /** 拆出一行的单元格 */
  const cells = (l: string) =>
    l.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim())

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i]
    const l = raw.trimEnd()
    // 代码块占位行：整块回填原始 HTML，不参与按行拆分，缩进才不会被打散
    const blk = l.match(/^%%BLOCK(\d+)%%$/)
    if (blk) {
      closeList()
      out.push(blocks[Number(blk[1])])
      continue
    }
    // 表格：当前行以 | 开头且下一行是分隔行，整块按表格渲染
    if (l.trim().startsWith('|') && i + 1 < lines.length && isTableSep(lines[i + 1])) {
      closeList()
      const head = cells(l)
      i += 2 // 跳过表头与分隔行
      const rows: string[][] = []
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.push(cells(lines[i]))
        i++
      }
      i-- // for 循环会自增，交回这一行
      const th = head.map((c) => `<th>${inline(c)}</th>`).join('')
      const tb = rows
        .map((r) => `<tr>${r.map((c) => `<td>${inline(c)}</td>`).join('')}</tr>`)
        .join('')
      out.push(`<div class="md-table-wrap"><table class="md-table"><thead><tr>${th}</tr></thead><tbody>${tb}</tbody></table></div>`)
      continue
    }
    const h = l.match(/^(#{1,4})\s+(.*)$/)
    if (h) {
      closeList()
      const lv = h[1].length
      out.push(`<h${lv} class="md-h md-h${lv}">${h[2]}</h${lv}>`)
    } else if (/^[-*]\s+/.test(l)) {
      if (inList !== 'ul') { closeList(); out.push('<ul>'); inList = 'ul' }
      // 任务列表：- [ ] 未完成 / - [x] 已完成
      const task = l.replace(/^[-*]\s+/, '').match(/^\[([ xX])\]\s*(.*)$/)
      if (task) {
        const done = task[1].toLowerCase() === 'x'
        out.push(`<li class="md-task"><span class="md-check${done ? ' is-done' : ''}">${done ? '✓' : ''}</span>${inline(task[2])}</li>`)
      } else {
        out.push(`<li>${l.replace(/^[-*]\s+/, '')}</li>`)
      }
    } else if (/^\d+[.)]\s+/.test(l)) {
      if (inList !== 'ol') { closeList(); out.push('<ol>'); inList = 'ol' }
      out.push(`<li>${l.replace(/^\d+[.)]\s+/, '')}</li>`)
    } else if (/^>\s?/.test(l)) {
      closeList()
      out.push(`<blockquote>${l.replace(/^>\s?/, '')}</blockquote>`)
    } else if (!l.trim()) {
      closeList()
    } else {
      // 独占一行的 **加粗小标题**：渲染成小标题而不是普通段落
      const bold = l.trim().match(/^\*\*(.+)\*\*$/)
      if (bold) {
        closeList()
        out.push(`<h4 class="md-h md-h4 md-subtitle">${bold[1]}</h4>`)
        continue
      }
      closeList()
      out.push(`<p>${inline(l)}</p>`)
    }
  }
  closeList()

  return out.join('\n')
}

/** 行内格式：**粗体** `代码` */
function inline(s: string): string {
  return s
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
}

const contentHtml = computed(() => renderMarkdown(lesson.value?.content || ''))

async function load(slug: string) {
  loading.value = true
  error.value = ''
  // 切换课时：先结算上一个课时的时长，避免两个课时的秒数混在一起。
  // 会话标识不用在这里清 —— ensureSessionKey 里比较「当前正在学的课时」即可自动区分：
  // 课时没变（刷新）就复用同一把 key，课时变了就换新 key、计为新的一次学习。
  const prevId = lesson.value?.id as number | undefined
  try {
    const r = await courseApi.lesson(slug)
    const newId = (r.lesson || r).id as number | undefined
    // 注意：结算必须在覆盖 lesson.value 之前做，
    // 否则会把旧课时的会话标识记到新课时头上，导致学习次数错记
    if (prevId && newId && prevId !== newId) {
      stopTimer(true)
    }
    // 后端返回的是平铺结构（无 lesson 嵌套）
    lesson.value = r.lesson || r
    snippets.value = r.snippets || []
    knowledge.value = r.knowledge || []
    prev.value = r.prev || null
    next.value = r.next || null
    if (newId) {
      void progress.loadOne(newId)
      // 进入新课时：重新开始计时
      startTimer(newId)
    }
    document.title = `${lesson.value?.title || '课时'} · Java 精通之路`
    window.scrollTo({ top: 0 })
  } catch (e) {
    error.value = errMsg(e)
  } finally {
    loading.value = false
  }
}

function askAboutThis() {
  agent.open()
  void agent.ask(`请帮我讲解「${lesson.value?.title}」这一节的重点，并给出常见坑。`)
}

// ------------------------------------------------------------------
// 代码实验室：把课程里的示例代码真正跑起来
// ------------------------------------------------------------------
/** 代码执行环境是否就绪（未就绪时禁用运行按钮并说明原因） */
const codeRuntime = ref<any>(null)
/** 正在运行的示例 id */
const runningSnippet = ref<number | null>(null)
/** 每个示例的运行结果：{ status, stdout, stderr, output, message, durationMs, success } */
const snippetRuns = ref<Record<number, any>>({})
/** 该课时的习题 */
const exercises = ref<any[]>([])
/** 只展示属于本课时的习题 */
const lessonExercises = computed(() => {
  const lid = lesson.value?.id
  if (!lid) return []
  return exercises.value.filter((e) => e.lessonId === lid)
})

async function loadCodeEnv() {
  try {
    codeRuntime.value = await codeApi.runtime()
  } catch {
    codeRuntime.value = { ready: false, note: '无法获取代码执行环境状态（后端可能未启动）' }
  }
}

/** 运行某个示例代码 */
async function runSnippet(s: any) {
  if (!codeRuntime.value?.ready || runningSnippet.value !== null) return
  runningSnippet.value = s.id
  try {
    const r = await codeApi.run(s.code, s.stdin || '')
    snippetRuns.value = { ...snippetRuns.value, [s.id]: r }
  } catch (e) {
    snippetRuns.value = {
      ...snippetRuns.value,
      [s.id]: {
        status: 'COMPILE_ERROR',
        success: false,
        stdout: '',
        stderr: '',
        output: '',
        message: errMsg(e),
        durationMs: 0,
      },
    }
  } finally {
    runningSnippet.value = null
  }
}

/** 把示例代码复制到编辑器（跳到习题页） */
function openInLab(s: any) {
  sessionStorage.setItem('javacourse.lab.snippet', JSON.stringify({ code: s.code, title: s.title }))
  void router.push({ name: 'exercises' })
}

onMounted(() => {
  window.addEventListener('scroll', onScroll, { passive: true })
  // 页面隐藏时结算并暂停计时：切走标签页不该继续累计时长
  document.addEventListener('visibilitychange', onVisibilityChange)
  // 关闭/刷新页面前用 keepalive 请求把最后的时长结算掉
  window.addEventListener('pagehide', onPageHide)
  void load(route.params.slug as string)
  void progress.loadMarks()
  void loadCodeEnv()
  void codeApi.exercises().then((list) => {
    exercises.value = list
  }).catch(() => {
    exercises.value = []
  })
})
onUnmounted(() => {
  window.removeEventListener('scroll', onScroll)
  document.removeEventListener('visibilitychange', onVisibilityChange)
  window.removeEventListener('pagehide', onPageHide)
  // 离开页面：只结算时长。
  // 会话标识不能在这里清 —— 刷新页面也会卸载组件，清掉会让刷新被误判成新的一次学习；
  // 作废旧标识统一交给 load() 里「真正切到另一个课时」的分支处理。
  stopTimer(true)
})
watch(() => route.params.slug, (s) => s && load(s as string))
</script>

<template>
  <div class="container lesson-page">
    <div v-if="loading" class="lesson__loading"><div class="spinner" /></div>

    <div v-else-if="error" class="card lesson__error">
      <p>{{ error }}</p>
      <RouterLink to="/" class="btn btn--mint">回首页</RouterLink>
    </div>

    <template v-else-if="lesson">
      <!-- 顶部标题 -->
      <header class="lesson__head card anim-pop">
        <div class="lesson__head-top">
          <RouterLink to="/" class="lesson__crumb">← 课程目录</RouterLink>
          <button class="btn btn--sm btn--sun" @click="askAboutThis">🐳 问鲸鲸</button>
        </div>
        <h1 class="lesson__title title-round">{{ lesson.title }}</h1>
        <p class="lesson__summary">{{ lesson.summary }}</p>
        <div class="lesson__meta">
          <span v-if="lesson.difficulty" class="badge badge--coral">{{ lesson.difficulty }}</span>
          <span v-if="lesson.durationMin" class="badge badge--mint">{{ lesson.durationMin }} 分钟</span>
          <span class="badge badge--sun">👁 {{ lesson.viewCount ?? 0 }} 次浏览</span>
          <span v-if="lessonStudyCount > 0" class="badge badge--mint">📘 我学了 {{ lessonStudyCount }} 次</span>
          <span v-if="lessonStudySeconds > 0" class="badge badge--lilac">⏱ 我学了 {{ lessonStudyMinutes }} 分钟</span>
          <span v-if="savedPct > 0 && !isCompleted" class="badge badge--lilac">已读 {{ savedPct }}%</span>
        </div>

        <!-- 阅读进度条 -->
        <div class="readbar" :title="`阅读进度 ${savedPct}%`">
          <div class="readbar__fill" :style="{ width: `${isCompleted ? 100 : savedPct}%` }" />
        </div>

        <!-- 操作条 -->
        <div class="lesson__actions">
          <button class="btn btn--sm" :class="isCompleted ? 'btn--mint' : 'btn--ghost'" @click="toggleDone">
            {{ isCompleted ? '✓ 已完成' : '标记完成' }}
          </button>
          <button class="btn btn--sm" :class="isFavorite ? 'btn--sun' : 'btn--ghost'" @click="toggleFav">
            {{ isFavorite ? '★ 已收藏' : '☆ 收藏本节' }}
          </button>
          <span v-if="saving" class="lesson__saving">进度保存中…</span>
        </div>
      </header>

      <div class="lesson__grid">
        <!-- 正文 -->
        <article class="lesson__body card">
          <div class="md-body" v-html="contentHtml" />

          <!-- 代码片段 -->
          <section v-if="snippets.length" class="snips">
            <div class="section-head">
              <span class="dot" /><h2>代码实验室</h2><span class="line" />
            </div>
            <p v-if="codeRuntime && !codeRuntime.ready" class="snips__env-warn">
              ⚠ {{ codeRuntime.note }}
            </p>
            <div v-for="s in snippets" :key="s.id" class="snip">
              <div class="snip__head">
                <span class="badge badge--lilac">{{ s.language || 'java' }}</span>
                <strong>{{ s.title }}</strong>
                <span v-if="s.runnable" class="snip__runnable">可运行</span>
                <span class="snip__actions">
                  <button
                    v-if="s.runnable"
                    class="btn btn--sm btn--mint"
                    :disabled="!codeRuntime?.ready || runningSnippet !== null"
                    @click="runSnippet(s)"
                  >
                    {{ runningSnippet === s.id ? '运行中…' : '▶ 运行' }}
                  </button>
                  <button class="btn btn--sm btn--ghost" @click="openInLab(s)">✎ 在编辑器中打开</button>
                </span>
              </div>
              <pre class="code"><code>{{ s.code }}</code></pre>
              <p v-if="s.explanation" class="snip__note">{{ s.explanation }}</p>

              <!-- 运行结果 -->
              <div v-if="snippetRuns[s.id]" class="snip__run">
                <div class="snip__run-head">
                  <span class="snip__run-status" :class="snippetRuns[s.id].success ? 'is-pass' : 'is-err'">
                    {{ snippetRuns[s.id].success ? '✓ 运行成功' : '✗ ' + snippetRuns[s.id].message }}
                  </span>
                  <span class="snip__run-time">{{ snippetRuns[s.id].durationMs }} ms</span>
                </div>
                <pre v-if="snippetRuns[s.id].output" class="snip__pre snip__pre--err">{{ snippetRuns[s.id].output }}</pre>
                <pre v-if="snippetRuns[s.id].stdout" class="snip__pre snip__pre--out">{{ snippetRuns[s.id].stdout }}</pre>
                <pre v-if="snippetRuns[s.id].stderr" class="snip__pre snip__pre--err">{{ snippetRuns[s.id].stderr }}</pre>
                <p v-if="s.expectedOut && snippetRuns[s.id].success" class="snip__expect">
                  期望输出：<code>{{ s.expectedOut }}</code>
                </p>
              </div>
            </div>
          </section>

          <!-- 本节习题 -->
          <section v-if="lessonExercises.length" class="snips">
            <div class="section-head">
              <span class="dot" /><h2>课后习题</h2><span class="line" />
            </div>
            <div class="ex-list">
              <RouterLink
                v-for="e in lessonExercises"
                :key="e.id"
                :to="`/exercise/${e.slug}`"
                class="ex-list__item"
              >
                <strong>{{ e.title }}</strong>
                <span class="badge badge--sun">{{ e.difficulty }}</span>
                <span class="ex-list__go">去做题 →</span>
              </RouterLink>
            </div>
          </section>

          <!-- 知识点 -->
          <section v-if="knowledge.length" class="kps">
            <div class="section-head">
              <span class="dot" /><h2>本节知识点</h2><span class="line" />
            </div>
            <div class="kps__grid">
              <div v-for="k in knowledge" :key="k.id" class="kp">
                <span class="badge badge--sun">{{ k.category }}</span>
                <strong class="kp__name">{{ k.name }}</strong>
                <p v-if="k.description" class="kp__desc">{{ k.description }}</p>
              </div>
            </div>
          </section>

          <!-- 上下课时 -->
          <nav class="lesson__nav">
            <RouterLink v-if="prev" :to="`/lesson/${prev.slug}`" class="lesson__nav-btn card">
              <span class="dir">← 上一节</span>
              <strong>{{ prev.title }}</strong>
            </RouterLink>
            <span v-else />
            <RouterLink v-if="next" :to="`/lesson/${next.slug}`" class="lesson__nav-btn card lesson__nav-btn--next">
              <span class="dir">下一节 →</span>
              <strong>{{ next.title }}</strong>
            </RouterLink>
          </nav>
        </article>

        <!-- 侧栏 -->
        <aside class="lesson__side">
          <div class="card side__card">
            <h3 class="title-round side__title">本节速记</h3>
            <ul class="side__list">
              <li v-for="k in knowledge" :key="k.id">{{ k.name }}</li>
              <li v-if="!knowledge.length" class="side__empty">暂无知识点标注</li>
            </ul>
          </div>

          <div class="card side__card side__card--whale">
            <img :src="ASSET_BASE + 'assets/agent/agent-ok.png'" alt="鲸鲸" class="side__whale" />
            <p class="side__quote">"没听懂就点上面的「问鲸鲸」，我会换个说法再讲一遍喵～"</p>
            <button class="btn btn--sm btn--primary" @click="askAboutThis">继续问</button>
          </div>
        </aside>
      </div>
    </template>
  </div>
</template>

<style scoped>
.lesson-page { padding-top: var(--space-lg); }
.lesson__loading { display: grid; place-items: center; padding: 70px 0; }
.lesson__error { padding: 40px; text-align: center; }
.lesson__error p { margin: 0 0 18px; color: var(--c-coral-deep); font-weight: 700; }

.lesson__head { padding: 26px 30px; margin-bottom: 20px; }
.lesson__head-top { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }
.lesson__crumb { font-size: 14px; color: var(--c-ink-faint); text-decoration: none; }
.lesson__crumb:hover { color: var(--c-coral); }
.lesson__title { margin: 0 0 8px; font-size: 32px; }
.lesson__summary { margin: 0 0 14px; font-size: 15px; color: var(--c-ink-soft); line-height: 1.8; }
.lesson__meta { display: flex; gap: 8px; flex-wrap: wrap; }

.readbar {
  margin-top: 16px;
  height: 14px;
  background: var(--c-cream-deep);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-full);
  overflow: hidden;
}
.readbar__fill {
  height: 100%;
  background: linear-gradient(90deg, var(--c-mint), var(--c-sun));
  transition: width .4s cubic-bezier(.34,1.4,.64,1);
}

.lesson__actions { display: flex; align-items: center; gap: 10px; margin-top: 16px; flex-wrap: wrap; }
.lesson__saving { font-size: 12px; color: var(--c-ink-faint); }

.lesson__grid { display: grid; grid-template-columns: 1fr 300px; gap: 20px; align-items: start; }
.lesson__body { padding: 28px 32px; }

.md-body :deep(.md-h) {
  margin: 26px 0 12px;
  font-family: var(--font-round);
  font-weight: 800;
}
.md-body :deep(.md-h1) { font-size: 25px; }
.md-body :deep(.md-h2) { font-size: 21px; padding-left: 12px; border-left: 6px solid var(--c-mint); }
.md-body :deep(.md-h3) { font-size: 18px; }
.md-body :deep(.md-h4) { font-size: 16px; }
/* 独占一行的加粗小标题 */
.md-body :deep(.md-subtitle) {
  margin: 20px 0 8px;
  color: var(--c-ink);
  font-weight: 700;
}
.md-body :deep(p) { margin: 12px 0; line-height: 1.95; }
.md-body :deep(ul), .md-body :deep(ol) { margin: 12px 0; padding-left: 26px; line-height: 2; }
.md-body :deep(li) { margin-bottom: 4px; }
/* 任务列表：- [ ] / - [x] */
.md-body :deep(.md-task) {
  list-style: none;
  display: flex;
  align-items: flex-start;
  gap: 8px;
}
.md-body :deep(.md-check) {
  flex: 0 0 auto;
  width: 16px;
  height: 16px;
  margin-top: 5px;
  border: var(--bw-base) solid var(--c-line);
  border-radius: 4px;
  background: var(--c-surface, #fff);
}
.md-body :deep(.md-check.is-done) {
  background: var(--c-mint);
  border-color: var(--c-mint);
  color: #fff;
  font-size: 12px;
  line-height: 14px;
  text-align: center;
}
.md-body :deep(strong) { color: var(--c-coral-deep); }
.md-body :deep(blockquote) {
  margin: 14px 0;
  padding: 12px 16px;
  background: var(--c-cream-deep);
  border-left: 6px solid var(--c-sun);
  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  color: var(--c-ink-soft);
}
.md-body :deep(code) {
  padding: 2px 7px;
  font-family: var(--font-mono);
  font-size: 13.5px;
  background: var(--c-cream-deep);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: 6px;
}
/* 表格：正文里的表格由 v-html 注入（不带 scoped 属性），必须用 :deep() 命中 */
.md-body :deep(.md-table-wrap) {
  margin: 16px 0;
  overflow-x: auto;
  border: var(--bw-base) solid var(--c-line);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
}
.md-body :deep(.md-table) {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}
.md-body :deep(.md-table th),
.md-body :deep(.md-table td) {
  padding: 10px 14px;
  text-align: left;
  border-bottom: var(--bw-thin) solid var(--c-line);
  vertical-align: top;
}
.md-body :deep(.md-table th) {
  background: var(--c-cream-deep);
  font-weight: 700;
  color: var(--c-ink);
  white-space: nowrap;
}
.md-body :deep(.md-table tbody tr:last-child td) { border-bottom: none; }
.md-body :deep(.md-table tbody tr:hover td) { background: var(--c-cream); }
/* 表格里的行内代码不要继承 code 块的高亮底色 */
.md-body :deep(.md-table code) { background: var(--c-cream-deep); }
@media (prefers-color-scheme: dark) {
  .md-body :deep(.md-table th),
  .md-body :deep(.md-table td) { border-color: var(--c-line-dark); }
  .md-body :deep(.md-table th) { background: rgba(255, 255, 255, 0.05); color: var(--code-ink-dark); }
  .md-body :deep(.md-table tbody tr:hover td) { background: rgba(255, 255, 255, 0.04); }
}
/* 代码块：正文里的代码块由 v-html 注入（不带 scoped 属性），必须用 :deep() 命中 */
.code,
.md-body :deep(.md-code) {
  margin: 14px 0;
  padding: 18px 20px;
  overflow-x: auto;
  background: var(--code-surface);
  border: var(--bw-base) solid var(--c-line);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  /* 代码块必须逐字符保留缩进、换行与空行，禁止浏览器折叠空白 */
  white-space: pre;
  tab-size: 4;
  -moz-tab-size: 4;
}
.code code,
.md-body :deep(.md-code code) {
  display: block;
  font-family: var(--font-mono);
  font-size: 13.5px;
  line-height: 1.75;
  background: none;
  border: none;
  padding: 0;
  white-space: pre;
  tab-size: 4;
  -moz-tab-size: 4;
}

/* 暗色主题下代码块与高亮色跟随系统偏好，保证明暗两套主题下缩进与配色都正常 */
@media (prefers-color-scheme: dark) {
  .code,
  .md-body :deep(.md-code) {
    background: var(--code-surface-dark);
    border-color: var(--c-line-dark);
  }
  .code .hljs,
  .md-body :deep(.md-code .hljs) { background: transparent; color: var(--code-ink-dark); }
  .code .hljs-comment, .code .hljs-quote,
  .md-body :deep(.md-code .hljs-comment), .md-body :deep(.md-code .hljs-quote) { color: #8b949e; font-style: italic; }
  .code .hljs-keyword, .code .hljs-selector-tag, .code .hljs-literal, .code .hljs-doctag,
  .md-body :deep(.md-code .hljs-keyword), .md-body :deep(.md-code .hljs-selector-tag),
  .md-body :deep(.md-code .hljs-literal), .md-body :deep(.md-code .hljs-doctag) { color: #ff7b72; }
  .code .hljs-string, .code .hljs-regexp, .code .hljs-addition,
  .md-body :deep(.md-code .hljs-string), .md-body :deep(.md-code .hljs-regexp),
  .md-body :deep(.md-code .hljs-addition) { color: #a5d6ff; }
  .code .hljs-number, .code .hljs-symbol, .code .hljs-bullet,
  .md-body :deep(.md-code .hljs-number), .md-body :deep(.md-code .hljs-symbol),
  .md-body :deep(.md-code .hljs-bullet) { color: #79c0ff; }
  .code .hljs-title, .code .hljs-section, .code .hljs-name,
  .md-body :deep(.md-code .hljs-title), .md-body :deep(.md-code .hljs-section),
  .md-body :deep(.md-code .hljs-name) { color: #d2a8ff; }
  .code .hljs-attr, .code .hljs-attribute, .code .hljs-variable, .code .hljs-template-variable,
  .md-body :deep(.md-code .hljs-attr), .md-body :deep(.md-code .hljs-attribute),
  .md-body :deep(.md-code .hljs-variable), .md-body :deep(.md-code .hljs-template-variable) { color: #ffa657; }
  .code .hljs-built_in, .code .hljs-type, .code .hljs-class .hljs-title,
  .md-body :deep(.md-code .hljs-built_in), .md-body :deep(.md-code .hljs-type),
  .md-body :deep(.md-code .hljs-class .hljs-title) { color: #7ee787; }
  .code .hljs-meta,
  .md-body :deep(.md-code .hljs-meta) { color: #8b949e; }
  .code .hljs-deletion,
  .md-body :deep(.md-code .hljs-deletion) { color: #ffdcd7; }
  .code .hljs-emphasis,
  .md-body :deep(.md-code .hljs-emphasis) { font-style: italic; }
  .code .hljs-strong,
  .md-body :deep(.md-code .hljs-strong) { font-weight: 600; }
}

.snips, .kps { margin-top: 34px; }
.snip { margin-bottom: 20px; }
.snip__head { display: flex; align-items: center; gap: 10px; margin-bottom: 4px; flex-wrap: wrap; }
.snip__note { margin: 4px 0 0; padding: 10px 14px; font-size: 13px; background: var(--c-cream-deep); border-radius: var(--radius-sm); color: var(--c-ink-soft); }

/* 代码实验室：环境提示 / 运行按钮 / 运行结果 */
.snips__env-warn {
  margin: 0 0 14px;
  padding: 10px 14px;
  font-size: 13px;
  background: var(--c-cream-deep);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-sm);
  color: var(--c-ink-soft);
}
.snip__runnable {
  padding: 1px 9px;
  background: #51cf66;
  border: 2px solid var(--c-line);
  border-radius: var(--radius-full);
  font-size: 11px;
  font-weight: 800;
  color: #14361a;
}
.snip__actions { margin-left: auto; display: flex; gap: 6px; }
.snip__run {
  margin-top: 10px;
  padding: 10px 12px;
  background: var(--c-cream);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-md);
}
.snip__run-head { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }
.snip__run-status {
  padding: 2px 11px;
  border: 2px solid var(--c-line);
  border-radius: var(--radius-full);
  font-size: 12px;
  font-weight: 800;
}
.snip__run-status.is-pass { background: #51cf66; color: #14361a; }
.snip__run-status.is-err { background: var(--c-coral); color: #fff; }
.snip__run-time { margin-left: auto; font-size: 11px; color: var(--c-ink-faint); }
.snip__pre {
  margin: 6px 0 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  font-family: 'Cascadia Code', Consolas, monospace;
  font-size: 12.5px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
  max-height: 300px;
  overflow: auto;
}
.snip__pre--out { background: #1e2544; color: #c8f7d0; }
.snip__pre--err { background: #3a1f2b; color: #ffd3d3; }
.snip__expect { margin: 8px 0 0; font-size: 12px; color: var(--c-ink-soft); }
.snip__expect code {
  background: var(--c-paper);
  border: 1px solid var(--c-line);
  border-radius: 4px;
  padding: 1px 6px;
  font-size: 11.5px;
  white-space: pre-wrap;
}

/* 习题列表 */
.ex-list { display: flex; flex-direction: column; gap: 8px; }
.ex-list__item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 14px;
  background: var(--c-cream);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-md);
  text-decoration: none;
  color: var(--c-ink);
  font-size: 14px;
  transition: transform .12s ease, background .12s ease;
}
.ex-list__item:hover { background: var(--c-sun); transform: translateX(3px); }
.ex-list__go { margin-left: auto; font-size: 12px; font-weight: 800; color: var(--c-coral-deep); }

.kps__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 12px; }
.kp {
  padding: 14px;
  background: var(--c-cream);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-md);
}
.kp__name { display: block; margin: 8px 0 4px; font-family: var(--font-round); }
.kp__desc { margin: 0; font-size: 12.5px; color: var(--c-ink-faint); line-height: 1.7; }

.lesson__nav { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-top: 34px; }
.lesson__nav-btn {
  display: flex;
  flex-direction: column;
  gap: 5px;
  padding: 15px 18px;
  text-decoration: none;
  color: var(--c-ink);
}
.lesson__nav-btn:hover { transform: translate(-3px, -3px); box-shadow: var(--shadow-lg); }
.lesson__nav-btn--next { text-align: right; }
.dir { font-size: 12px; color: var(--c-coral-deep); font-weight: 700; }
.lesson__nav-btn strong { font-family: var(--font-round); font-size: 15px; }

.lesson__side { position: sticky; top: calc(var(--nav-h) + 20px); display: flex; flex-direction: column; gap: 16px; }
.side__card { padding: 20px; }
.side__title { margin: 0 0 12px; font-size: 18px; }
.side__list { margin: 0; padding-left: 20px; font-size: 13.5px; line-height: 2; color: var(--c-ink-soft); }
.side__empty { color: var(--c-ink-faint); }
.side__card--whale { text-align: center; background: linear-gradient(160deg, var(--c-sun), var(--c-peach)); }
.side__whale { width: 100px; height: 100px; }
.side__quote { margin: 10px 0 14px; font-size: 13px; line-height: 1.8; font-weight: 700; }

@media (max-width: 980px) {
  .lesson__grid { grid-template-columns: 1fr; }
  .lesson__side { position: static; }
  .lesson__title { font-size: 25px; }
}
</style>
