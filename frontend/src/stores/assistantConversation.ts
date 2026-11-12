import { computed, ref, watch } from 'vue'
import { defineStore, storeToRefs } from 'pinia'
import { useRoute } from 'vue-router'
import { aiApi, type AssistantRequestOptions, type Citation } from '@/api'
import { isAxiosError } from 'axios'
import { getToken } from '@/api/http'
import { useAuthStore } from './auth'

export const WHALE_IDENTITY = 'Ciallo~ 我是鲸鲸，Java 精通之路的学习助教。我可以讲课程知识、帮你读懂 Java 代码和报错，也能给练习提示。'
export const WHALE_GREETING = 'Ciallo~ 我是鲸鲸，陪你学 Java。可以问我课程知识、代码报错，或请我给一道练习题的第一步提示。'
export const WHALE_PRIVACY_NOTICE = '请勿发送密码、密钥或个人资料。普通问题可能发送给模型服务商，对话只在当前页面保留。'
export const WHALE_LOCAL_NOTICE = '仅在站内检索课程资料。请先移除密码、密钥和个人资料。'
export const WHALE_INTRO_QUESTION = '你是谁？'
export const MAX_QUESTION_LENGTH = 6000

const BLOCKED_QUESTION = '问题已拦截'
const PRIVACY_REPLY = '为保护隐私，请删去密码、密钥或个人资料，再发一份脱敏示例。我可以帮你分析其中的 Java 问题。'
const MAX_HISTORY = 60
const SECRET_PATTERNS = [
  /-----BEGIN (?:[\w ]+ )?PRIVATE KEY-----/i,
  /(?<![\w-])(?:sk-[\w-]{12,}|gh[pousr]_\w{12,}|github_pat_\w{12,}|(?:AKIA|ASIA)[A-Z0-9]{16}|xox[baprs]-[\w-]{12,}|AIza[\w-]{30,})(?![\w-])/,
  /\beyJ[\w-]{6,}\.[\w-]{6,}\.[\w-]{6,}\b/,
  /\b(?:bearer|basic)\s+[A-Za-z0-9/+_.~=-]{8,}/i,
  /\b[a-z][a-z0-9+.-]*:\/\/[^\s:/@]+:[^\s/@]+@/i,
  /(?<!\d)1[3-9]\d(?:[ \t-]?\d){8}(?!\d)/,
  /(?<!\d)[1-9]\d{9}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx](?!\d)/,
]
const LABELED_CREDENTIAL = /(?:\b(?:[\w]+[_-])?(?:password|passwd|pwd|api[_ -]?key|access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|secret[_ -]?key|session[_ -]?token|javacourse_token|authorization)\b|密码|密钥|口令|令牌)["']?[ \t]*(?:[:=]|是|为)[ \t]*(?:"([^"\r\n]+)"|'([^'\r\n]+)'|([^\s,;，；)<>"']+))/gi
const PLACEHOLDER = /^(?:\$\{[^}]+\}|<[^>]+>|\[?(?:占位符|已脱敏)\]?|\*{3,}|x{4,}|null|none|(?:your|example|dummy|placeholder|redacted|replace)[\w.-]*|(?:System\.getenv|System\.getProperty|env\.get)\(.*)$/i

function containsPrivateData(text: string): boolean {
  const value = text.normalize('NFKC').replace(/[\u200b-\u200d\ufeff]/g, '')
  if (SECRET_PATTERNS.some((pattern) => pattern.test(value))) return true
  for (const match of value.matchAll(LABELED_CREDENTIAL)) {
    const credential = match[1] ?? match[2] ?? match[3]
    if (!PLACEHOLDER.test(credential.trim())) return true
  }
  for (const [, body] of value.matchAll(/(?<![\w-])([\w-]{40,512})\.[\w-]{43}(?![\w-]|\.[\w-])/g)) {
    try {
      const decoded = atob(body.replace(/-/g, '+').replace(/_/g, '/'))
      if (/^\d+\|[^|]+\|[^|]+\|\d+\|\d+\|[a-f0-9]{32}$/.test(decoded)) return true
    } catch { /* Other dot-separated text is not an account token. */ }
  }
  return Array.from(value.matchAll(/[\w.%+-]+@([a-z0-9.-]+\.[a-z]{2,})/gi)).some((match) =>
    !/^(?:example\.(?:com|net|org)|[\w.-]+\.(?:example|test|invalid|localhost))$/i.test(match[1]),
  )
}

function personalReply(question: string): string | undefined {
  const q = question.normalize('NFKC').toLowerCase().replace(/[\s，。！？,.!?~～]+/g, '')
  if (/^(?:请问|请)?(?:你是谁|你是什么|你叫什么(?:名字)?|你的名字是什么|你是做什么的|介绍(?:一下)?你自己|(?:做个|做一下)?自我介绍|whoareyou|whatsyourname|what'syourname)$/.test(q)) {
    return WHALE_IDENTITY
  }
  if (/^(?:你能做什么|你会做什么|你会什么|你能帮我什么|你有什么功能|怎么用|我该怎么用你|whatcanyoudo)$/.test(q)) {
    return '我可以解释 Java 概念、分析脱敏后的代码和报错，也能给练习提示。我通常先带你找思路，再给一个短例子。你可以先问我“数组下标为什么从 0 开始？”'
  }
  if (/^(?:你好(?:呀|啊)?|您好|嗨|哈喽|鲸鲸你好|hello|hi|ciallo)$/.test(q)) return WHALE_GREETING
  if (/^(?:你是真人吗|你是机器人吗|你是AI吗|你是ai吗|areyouhuman|areyouanai)$/.test(q)) {
    return '我是鲸鲸，一位 AI 学习助教。你可以问我 Java 课程知识、代码报错，或者请我给你一个练习提示。'
  }
  if (/^(?:你能看到什么|你能(?:看到|看见|读取|访问|查看)我的(?:账号(?:信息)?|数据|隐私|密码|密钥|个人资料|学习记录)吗|你会保存(?:我的)?(?:聊天|对话|聊天记录)吗|你怎么保护(?:我的)?隐私|whatdatacanyousee|canyouseemydata|doyoustorechathistory)$/.test(q)) {
    return '我只能根据这次发来的问题和公开课程资料答疑，无法查看账号资料、学习记录或站点内部配置。普通问题可能发送给模型服务商，贴代码前请先删去密码、密钥和个人资料。'
  }
}

export function isLessonSlug(slug: string): boolean {
  return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)
}

export function useAssistantRequestOptions() {
  const route = useRoute()
  const auth = useAuthStore()
  const conversation = useAssistantConversation()
  const lessonSlug = computed(() => {
    const slug = route.params.slug
    return (route.name === 'lesson' || route.name === 'lesson-lab')
      && typeof slug === 'string' && isLessonSlug(slug) ? slug : undefined
  })
  watch(lessonSlug, () => { conversation.includeLesson = false }, { flush: 'sync' })
  watch(() => auth.token, () => {
    conversation.localOnly = false
    conversation.includeLesson = false
  }, { flush: 'sync' })

  function requestOptions(): AssistantRequestOptions {
    return { localOnly: conversation.localOnly, lessonSlug: conversation.includeLesson ? lessonSlug.value : undefined }
  }

  const { localOnly, includeLesson } = storeToRefs(conversation)
  return { localOnly, includeLesson, lessonSlug, requestOptions }
}

type ReplySource = 'built-in' | 'course' | 'model' | 'unavailable'

interface ChatMessage {
  id: number
  role: 'user' | 'assistant'
  content: string
  citations?: Citation[]
  pending?: boolean
}

export const useAssistantConversation = defineStore('assistantConversation', () => {
  const auth = useAuthStore()
  const messages = ref<ChatMessage[]>([])
  const draft = ref('')
  const localOnly = ref(false)
  const includeLesson = ref(false)
  const loading = ref(false)
  const source = ref<ReplySource | null>(null)
  let seq = 0
  let activeRequest: AbortController | null = null

  async function ask(question: string, options: AssistantRequestOptions = {}) {
    const q = question.trim()
    if (!q || loading.value) return false
    const requestToken = getToken()
    if (requestToken !== auth.token) {
      clearHistory()
      return false
    }

    const privateInput = containsPrivateData(q)
    const tooLong = q.length > MAX_QUESTION_LENGTH
    let localAnswer = personalReply(q)
    if (privateInput) localAnswer = PRIVACY_REPLY
    else if (tooLong) localAnswer = `请把问题缩短到 ${MAX_QUESTION_LENGTH} 字符以内。可以只保留相关代码和报错。`
    else if (!localAnswer && !requestToken) localAnswer = '登录后就可以继续问我 Java 课程和代码问题。'
    const questionId = ++seq
    const answerId = ++seq
    const displayedQuestion = privateInput ? BLOCKED_QUESTION : tooLong ? '问题太长' : q
    messages.value = [
      ...messages.value.slice(-(MAX_HISTORY - 2)),
      { id: questionId, role: 'user', content: localAnswer ? displayedQuestion : '正在提交问题…' },
      { id: answerId, role: 'assistant', content: localAnswer || '', pending: !localAnswer },
    ]
    if (localAnswer) {
      source.value = 'built-in'
      return true
    }

    const request = new AbortController()
    activeRequest = request
    loading.value = true

    function finish(answer: string, answerSource: ReplySource, displayedQuestion: string, citations?: Citation[]) {
      if (activeRequest !== request) return false
      if (getToken() !== requestToken) {
        clearHistory()
        return false
      }
      const user = messages.value.find((m) => m.id === questionId)
      const reply = messages.value.find((m) => m.id === answerId)
      if (user) user.content = displayedQuestion
      if (reply) {
        reply.content = answer
        reply.citations = citations
        reply.pending = false
      }
      source.value = answerSource
      return true
    }

    try {
      const result = await aiApi.ask(q, requestToken, request.signal, options)
      if (result.blocked) {
        const reply = typeof result.answer === 'string' && !containsPrivateData(result.answer) ? result.answer : PRIVACY_REPLY
        return finish(reply, 'built-in', BLOCKED_QUESTION)
      } else if (typeof result.answer !== 'string' || !result.answer.trim()) {
        return finish(offlineReply(q), 'unavailable', '问题未收到有效回复')
      } else if (containsPrivateData(result.answer)) {
        return finish('这条回答可能包含敏感信息，已隐藏。请用脱敏示例重新提问。', 'built-in', BLOCKED_QUESTION)
      } else {
        const citations = result.citations?.filter((c) =>
          typeof c?.title === 'string' && typeof c.slug === 'string' && isLessonSlug(c.slug) && !containsPrivateData(c.title),
        )
        const answerSource = result.provider && result.provider !== 'local'
          ? 'model'
          : options.localOnly || result.degraded !== false ? 'course' : 'built-in'
        return finish(result.answer, answerSource, q, citations)
      }
    } catch (error) {
      const limited = isAxiosError(error) && error.response?.status === 429
      const reply = limited ? '提问太频繁，请等一分钟再试。' : offlineReply(q)
      return finish(reply, 'unavailable', limited ? '请求频率过高' : '问题未收到有效回复')
    } finally {
      if (activeRequest === request) {
        activeRequest = null
        loading.value = false
      }
    }
  }

  function clearHistory() {
    activeRequest?.abort()
    activeRequest = null
    loading.value = false
    messages.value = []
    draft.value = ''
    source.value = null
  }

  return { messages, draft, loading, source, localOnly, includeLesson, ask, clearHistory }
})

function offlineReply(question: string): string {
  const topics: [RegExp, string][] = [
    [/线程|thread|并发|锁|lock|synchron/i, '可以先在课程目录找线程池、线程状态或锁相关的课时。'],
    [/集合|list|map|hash/i, '可以先在课程目录找集合框架、List 或 HashMap。'],
    [/jvm|内存|gc|垃圾回收/i, '可以先在课程目录找 JVM 内存和垃圾回收相关的课时。'],
    [/string|字符串/i, '可以先在课程目录找字符串和常用 API。'],
    [/异常|exception|try/i, '可以先在课程目录找异常处理。'],
    [/数组|array/i, '可以先看数组课的关键代码，试着按下标读取一个元素。'],
  ]
  const topic = topics.find(([pattern]) => pattern.test(question))
  return `鲸鲸暂时连不上助教服务。${topic?.[1] || '你可以用顶部搜索找相关课时，也可以稍后再试。'}`
}
