import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'
import { aiApi, type AskResult } from '@/api'

/**
 * 桌宠状态机
 *
 * 移植自 dsh-pet 的动作池概念，但做了裁剪——浏览器里只保留教学场景真正需要的 5 态：
 *
 *   idle     待机：呼吸循环
 *   thinking 思考：等待模型响应（气泡显示加载点）
 *   talking  说话：正在播放回答（气泡展开）
 *   dragging 拖拽：被鼠标/手指拎着
 *   happy    答完/打招呼：雀跃一下再待机
 *
 * dsh-pet 原生有 106 个动作视频、6 个事件池、完整物理抛掷系统。
 * 浏览器移植只取「与 AI 助教交互直接相关」的那一小撮，理由见 README。
 */
export type PetState = 'idle' | 'thinking' | 'talking' | 'dragging' | 'happy'

/**
 * 状态 → 动画文件（webm）映射。
 *
 * 素材取自 dsh-pet 的 assets/webm（原文件名是中文，这里改成 ASCII：
 * 避免各平台文件系统与 HTTP 层的 URL 编码差异，中文名在部分环境下会 400）。
 * 原始对应关系：
 *   idle     ← 待机呼吸休闲      thinking ← 工作状态-思考冒泡
 *   talking  ← 深度思考碎碎念    happy    ← 工作状态-雀跃庆祝
 *   dragging ← 被鼠标拖拽悬空反馈
 */
/**
 * 静态资源基址。
 *
 * GitHub Pages 可能部署在子路径（<user>.github.io/<repo>/），此时绝对路径
 * /pet/xxx.webm 会 404。用 import.meta.env.BASE_URL 统一拼接，
 * 本地 dev 与根路径部署时 BASE_URL 为 '/'，行为不变。
 */
const ASSET_BASE = import.meta.env.BASE_URL || '/'

export const PET_ANIMATIONS: Record<PetState, string> = {
  idle: `${ASSET_BASE}pet/idle.webm`,
  thinking: `${ASSET_BASE}pet/thinking.webm`,
  talking: `${ASSET_BASE}pet/talking.webm`,
  dragging: `${ASSET_BASE}pet/dragging.webm`,
  happy: `${ASSET_BASE}pet/happy.webm`,
}

/** 气泡里的一条消息 */
export interface PetMessage {
  id: number
  role: 'user' | 'assistant'
  content: string
  pending?: boolean
  citations?: { title: string; slug: string }[]
  /** 回答来源：backend=走后端代理，direct=浏览器直连用户自填的接口，local=本地兜底 */
  source?: string
}

/**
 * AI 接口配置。
 *
 * 三种模式，按可用性自动降级：
 *   backend —— 走本项目后端的 /api/ai/ask（由后端持有 Key，最安全）
 *   direct  —— 浏览器直连用户填写的 OpenAI 兼容端点（Key 存在本地 localStorage）
 *   local   —— 无任何可用通道时的本地兜底（纯前端模板回复）
 */
export interface PetAiConfig {
  mode: 'backend' | 'direct' | 'local'
  /** OpenAI 兼容端点根地址（不含 /v1/chat/completions） */
  baseUrl: string
  apiKey: string
  model: string
  /** 自定义系统提示词（留空用默认） */
  systemPrompt: string
}

export const DEFAULT_AI_CONFIG: PetAiConfig = {
  mode: 'backend',
  baseUrl: '',
  apiKey: '',
  model: 'gpt-4o-mini',
  systemPrompt: '',
}

const CONFIG_KEY = 'javacourse.pet.aiConfig'
const HISTORY_KEY = 'javacourse.pet.history'
const MAX_HISTORY = 60

let seq = 0

/** 读配置：localStorage 不可用时返回默认配置 */
function loadConfig(): PetAiConfig {
  try {
    const raw = localStorage.getItem(CONFIG_KEY)
    if (raw) {
      const p = JSON.parse(raw)
      return {
        mode: p.mode === 'direct' || p.mode === 'local' ? p.mode : 'backend',
        baseUrl: typeof p.baseUrl === 'string' ? p.baseUrl : '',
        apiKey: typeof p.apiKey === 'string' ? p.apiKey : '',
        model: typeof p.model === 'string' && p.model ? p.model : 'gpt-4o-mini',
        systemPrompt: typeof p.systemPrompt === 'string' ? p.systemPrompt : '',
      }
    }
  } catch {
    /* 忽略：解析失败用默认 */
  }
  return { ...DEFAULT_AI_CONFIG }
}

/** 读历史：只保留已完成的对话，pending 的半截消息丢弃 */
function loadHistory(): PetMessage[] {
  try {
    const raw = localStorage.getItem(HISTORY_KEY)
    if (raw) {
      const arr = JSON.parse(raw)
      if (Array.isArray(arr)) {
        return arr
          .filter((m: any) => m && (m.role === 'user' || m.role === 'assistant'))
          .map((m: any, i: number) => ({
            id: ++seq,
            role: m.role,
            content: String(m.content ?? ''),
            citations: Array.isArray(m.citations) ? m.citations : undefined,
            source: m.source,
          }))
      }
    }
  } catch {
    /* 忽略 */
  }
  return []
}

export const usePetStore = defineStore('pet', () => {
  const state = ref<PetState>('idle')
  const bubbleOpen = ref(false)
  const loading = ref(false)
  const messages = ref<PetMessage[]>(loadHistory())
  const hint = ref('点我提问喵～')

  /** 当前生效的通道，用于在气泡角标提示用户（openai=大模型 / local=本地兜底） */
  const provider = ref<string>('local')
  const degraded = ref(true)
  /** 最近一次请求的失败原因（用于在气泡里明确提示「为什么没走大模型」） */
  const lastError = ref('')

  const aiConfig = ref<PetAiConfig>(loadConfig())

  const animation = computed(() => PET_ANIMATIONS[state.value])

  /** 气泡里最后一条助手消息（用于打字机效果） */
  const lastAnswer = computed(() => {
    const list = messages.value
    for (let i = list.length - 1; i >= 0; i--) {
      if (list[i].role === 'assistant') return list[i]
    }
    return null
  })

  /** 是否已配置可用的直连接口（直连模式下必须同时有地址和 Key） */
  const directConfigured = computed(
    () =>
      aiConfig.value.mode === 'direct' &&
      !!aiConfig.value.baseUrl.trim() &&
      !!aiConfig.value.apiKey.trim(),
  )

  /** 当前实际会走的通道说明，用于设置面板展示 */
  const effectiveChannel = computed(() => {
    if (aiConfig.value.mode === 'local') return 'local'
    if (aiConfig.value.mode === 'direct') {
      return directConfigured.value ? 'direct' : 'local'
    }
    return 'backend'
  })

  function setState(s: PetState) {
    state.value = s
  }

  /** 播完一次性动画后自动回待机 */
  function flash(s: PetState, ms = 2200) {
    state.value = s
    window.setTimeout(() => {
      if (state.value === s) state.value = 'idle'
    }, ms)
  }

  function openBubble() {
    bubbleOpen.value = true
    if (state.value === 'idle') flash('happy', 1800)
  }

  function closeBubble() {
    bubbleOpen.value = false
    if (state.value === 'talking') state.value = 'idle'
  }

  function toggleBubble() {
    bubbleOpen.value ? closeBubble() : openBubble()
  }

  /** 持久化历史对话（关闭气泡不丢，下次打开还在） */
  function persistHistory() {
    try {
      const slim = messages.value
        .filter((m) => !m.pending)
        .slice(-MAX_HISTORY)
        .map((m) => ({ role: m.role, content: m.content, citations: m.citations, source: m.source }))
      localStorage.setItem(HISTORY_KEY, JSON.stringify(slim))
    } catch {
      /* 忽略：隐私模式等场景下写不了 */
    }
  }

  /** 持久化 AI 配置 */
  function persistConfig() {
    try {
      localStorage.setItem(CONFIG_KEY, JSON.stringify(aiConfig.value))
    } catch {
      /* 忽略 */
    }
  }

  function updateConfig(patch: Partial<PetAiConfig>) {
    aiConfig.value = { ...aiConfig.value, ...patch }
    persistConfig()
  }

  function resetConfig() {
    aiConfig.value = { ...DEFAULT_AI_CONFIG }
    persistConfig()
  }

  /**
   * 向鲸鲸提问。
   *
   * 降级策略（前端侧兜底）：后端不可达时不让用户看到空白气泡，
   * 而是回一条本地预设回复，功能不中断。
   */
  async function ask(question: string) {
    const q = question.trim()
    if (!q || loading.value) return
    messages.value.push({ id: ++seq, role: 'user', content: q })
    const replyId = ++seq
    messages.value.push({ id: replyId, role: 'assistant', content: '', pending: true })
    loading.value = true
    state.value = 'thinking'
    lastError.value = ''

    try {
      const r: AskResult = await callAi(q)
      const item = messages.value.find((m) => m.id === replyId)
      if (item) {
        item.content = r.answer
        item.citations = r.citations
        item.pending = false
        item.source = r.provider
      }
      provider.value = (r as any).provider || 'local'
      degraded.value = (r as any).degraded !== false
      state.value = 'talking'
      flash('happy', 2400)
    } catch (e: any) {
      const item = messages.value.find((m) => m.id === replyId)
      const reason = e?.message || String(e)
      lastError.value = reason
      if (item) {
        // 直连模式下若接口没配好，明确告知原因，而不是含糊地说「连不上」
        item.content =
          aiConfig.value.mode === 'direct' && !directConfigured.value
            ? '呜哇，鲸鲸还没接上你的 AI 接口喵～\n\n请在气泡右上角的「⚙ 设置」里填写：\n'
              + '· 接口地址（OpenAI 兼容，例如 https://api.deepseek.com）\n'
              + '· API Key\n\n填好之后我就能直接回答啦！'
            : offlineReply(q)
        item.pending = false
        item.source = 'local'
      }
      provider.value = 'local'
      degraded.value = true
      state.value = 'idle'
    } finally {
      loading.value = false
      persistHistory()
    }
  }

  /**
   * 按当前配置调用 AI。
   * backend → 本项目后端代理；direct → 浏览器直连用户填写的端点；local → 直接抛错走兜底。
   */
  async function callAi(q: string): Promise<AskResult> {
    const mode = aiConfig.value.mode

    if (mode === 'local') {
      throw new Error('当前设置为「仅本地兜底」，未接入任何大模型')
    }

    if (mode === 'direct') {
      if (!directConfigured.value) {
        throw new Error('未配置接口地址或 API Key')
      }
      return callDirect(q)
    }

    // backend：走项目后端
    return aiApi.ask(q)
  }

  /**
   * 浏览器直连 OpenAI 兼容端点。
   *
   * 说明：Key 只存在浏览器 localStorage，不经过本项目后端，
   * 代价是浏览器会直接向第三方发请求（CORS 策略需对方放行）。
   * 想避免 Key 暴露在浏览器，就用 backend 模式让后端代理。
   */
  async function callDirect(q: string): Promise<AskResult> {
    const cfg = aiConfig.value
    const root = cfg.baseUrl.trim().replace(/\/+$/, '')
    const url = root.endsWith('/chat/completions') ? root : root + '/v1/chat/completions'

    // 带上前文，让多轮对话有上下文
    const history = messages.value
      .filter((m) => !m.pending && m.content)
      .slice(-10)
      .map((m) => ({ role: m.role, content: m.content }))

    const sys =
      cfg.systemPrompt.trim() ||
      '你是「鲸鲸」，一个活泼亲切的 Java 课程助教，回答用中文，技术讲解必须严谨准确。'

    const started = Date.now()
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${cfg.apiKey.trim()}`,
      },
      body: JSON.stringify({
        model: cfg.model.trim() || 'gpt-4o-mini',
        messages: [{ role: 'system', content: sys }, ...history, { role: 'user', content: q }],
        temperature: 0.6,
        max_tokens: 1500,
      }),
    })

    if (!resp.ok) {
      const body = await resp.text().catch(() => '')
      throw new Error(`AI 接口返回 HTTP ${resp.status}${body ? '：' + body.slice(0, 200) : ''}`)
    }
    const data = await resp.json()
    const answer = data?.choices?.[0]?.message?.content
    if (!answer) {
      throw new Error('AI 接口响应中没有 message.content')
    }
    return {
      answer: String(answer),
      citations: [],
      sessionId: 0,
      latencyMs: Date.now() - started,
      agent: {} as any,
      provider: 'direct',
      degraded: false,
    }
  }

  function reset() {
    messages.value = []
    state.value = 'idle'
    loading.value = false
    bubbleOpen.value = false
    lastError.value = ''
    try {
      localStorage.removeItem(HISTORY_KEY)
    } catch {
      /* 忽略 */
    }
  }

  /** 只清空对话，不动 AI 配置 */
  function clearHistory() {
    messages.value = []
    lastError.value = ''
    try {
      localStorage.removeItem(HISTORY_KEY)
    } catch {
      /* 忽略 */
    }
  }

  // 配置变化时立即落盘
  watch(aiConfig, () => persistConfig(), { deep: true })

  return {
    state,
    bubbleOpen,
    loading,
    messages,
    hint,
    provider,
    degraded,
    lastError,
    animation,
    lastAnswer,
    aiConfig,
    directConfigured,
    effectiveChannel,
    setState,
    flash,
    openBubble,
    closeBubble,
    toggleBubble,
    ask,
    reset,
    clearHistory,
    updateConfig,
    resetConfig,
  }
})

/**
 * 离线预设回复 —— 后端完全不可达时的最后兜底。
 *
 * 目标不是「答得好」，而是「不中断」：给出一条有指向性的引导，
 * 让用户能继续用网站（去目录、搜关键词、问具体问题），而不是对着报错发呆。
 */
function offlineReply(q: string): string {
  const kw = q.toLowerCase()
  const rules: [RegExp, string][] = [
    [/线程|thread|并发|池/, '并发这块建议先看「模块 3 · 并发编程」里的线程池与线程状态流转；\n提问时可以带上具体的 API 名（比如 `ThreadPoolExecutor`），我能定位得更准喵～'],
    [/锁|lock|synchron/i, '锁相关的内容在「模块 3 · 并发编程」；\n`synchronized` / `ReentrantLock` / `volatile` 三者的语义差异我也可以展开讲～'],
    [/集合|list|map|hash/i, '集合框架在「模块 2 · 核心基础」；\n你直接问「HashMap 为什么线程不安全」这种具体问题，我答得更准喵～'],
    [/jvm|内存|gc|垃圾回收/i, 'JVM 与垃圾回收在「模块 5 · 性能与调优」；\n内存溢出、GC 调优这些细节都可以继续问我～'],
    [/string|字符串|api/i, '字符串与常用 API 在「模块 2 · 核心基础」；\n说出你要用的方法名，我直接给你示例代码～'],
    [/异常|exception|try/i, '异常处理在「模块 2 · 核心基础」；\n受检异常与非受检异常的取舍我也可以讲清楚～'],
  ]
  for (const [re, tip] of rules) {
    if (re.test(kw)) {
      return `呜哇，鲸鲸的模型线缆暂时松了，先给你指个路喵～\n\n${tip}\n\n（网络恢复后我就能直接回答啦）`
    }
  }
  return `呜哇，鲸鲸现在连不上模型服务了喵……\n\n不过你可以先试试：\n- 顶部搜索框搜关键词（如「线程池」「HashMap」）\n- 「课程目录」按 6 个模块浏览，共 42 课时\n- 把问题换个更具体的说法，我恢复后马上能答`
}
