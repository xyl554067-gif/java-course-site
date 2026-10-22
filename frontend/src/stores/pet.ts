import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
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
 *   happy    答完/打招呼：雀跃一下再回待机
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
export const PET_ANIMATIONS: Record<PetState, string> = {
  idle: '/pet/idle.webm',
  thinking: '/pet/thinking.webm',
  talking: '/pet/talking.webm',
  dragging: '/pet/dragging.webm',
  happy: '/pet/happy.webm',
}

/** 气泡里的一条消息 */
export interface PetMessage {
  id: number
  role: 'user' | 'assistant'
  content: string
  pending?: boolean
  citations?: { title: string; slug: string }[]
}

let seq = 0

export const usePetStore = defineStore('pet', () => {
  const state = ref<PetState>('idle')
  const bubbleOpen = ref(false)
  const loading = ref(false)
  const messages = ref<PetMessage[]>([])
  const hint = ref('点我提问喵～')

  /** 当前生效的通道，用于在气泡角标提示用户（openai=大模型 / local=本地兜底） */
  const provider = ref<string>('local')
  const degraded = ref(true)

  const animation = computed(() => PET_ANIMATIONS[state.value])

  /** 气泡里最后一条助手消息（用于打字机效果） */
  const lastAnswer = computed(() => {
    const list = messages.value
    for (let i = list.length - 1; i >= 0; i--) {
      if (list[i].role === 'assistant') return list[i]
    }
    return null
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

    try {
      const r: AskResult = await aiApi.ask(q)
      const item = messages.value.find((m) => m.id === replyId)
      if (item) {
        item.content = r.answer
        item.citations = r.citations
        item.pending = false
      }
      provider.value = (r as any).provider || 'local'
      degraded.value = (r as any).degraded !== false
      state.value = 'talking'
      flash('happy', 2400)
    } catch (e: any) {
      const item = messages.value.find((m) => m.id === replyId)
      if (item) {
        item.content = offlineReply(q)
        item.pending = false
      }
      provider.value = 'local'
      degraded.value = true
      state.value = 'idle'
    } finally {
      loading.value = false
    }
  }

  function reset() {
    messages.value = []
    state.value = 'idle'
    loading.value = false
    bubbleOpen.value = false
  }

  return {
    state,
    bubbleOpen,
    loading,
    messages,
    hint,
    provider,
    degraded,
    animation,
    lastAnswer,
    setState,
    flash,
    openBubble,
    closeBubble,
    toggleBubble,
    ask,
    reset,
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
