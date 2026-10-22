import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { aiApi, type AgentProfile, type Citation } from '@/api'

export interface ChatMessage {
  id: number
  role: 'user' | 'assistant'
  content: string
  citations?: Citation[]
  /** 助手消息的思考态标记 */
  pending?: boolean
}

export type AgentMood = 'idle' | 'happy' | 'think' | 'ok'

const MOOD_FALLBACK: Record<AgentMood, string> = {
  idle: '/assets/agent/agent-idle.png',
  happy: '/assets/agent/agent-happy.png',
  think: '/assets/agent/agent-think.png',
  ok: '/assets/agent/agent-ok.png',
}

export const useAgentStore = defineStore('agent', () => {
  const profile = ref<AgentProfile | null>(null)
  const messages = ref<ChatMessage[]>([])
  const mood = ref<AgentMood>('idle')
  const loading = ref(false)
  const panelOpen = ref(false)

  let seq = 0
  const nextId = () => ++seq

  const avatar = computed(() => {
    const p = profile.value
    if (!p) return MOOD_FALLBACK[mood.value]
    const a = p.avatars as any
    if (Array.isArray(a)) {
      const idx = ['idle', 'happy', 'think', 'ok'].indexOf(mood.value)
      return a[idx] ?? a[0] ?? MOOD_FALLBACK[mood.value]
    }
    if (a && typeof a === 'object') {
      return a[mood.value] ?? a.idle ?? MOOD_FALLBACK[mood.value]
    }
    return MOOD_FALLBACK[mood.value]
  })

  async function loadProfile() {
    if (profile.value) return
    try {
      profile.value = await aiApi.agent()
    } catch {
      profile.value = {
        key: 'whale',
        name: '鲸鲸',
        title: 'Ciallo~ 课程助教',
        greeting: 'Ciallo~ 我是鲸鲸！有什么不懂的尽管问我喵～',
        moods: ['idle', 'happy', 'think', 'ok'],
        avatars: MOOD_FALLBACK,
      }
    }
  }

  function open() {
    panelOpen.value = true
    mood.value = 'happy'
    void loadProfile()
  }

  function close() {
    panelOpen.value = false
    mood.value = 'idle'
  }

  function toggle() {
    panelOpen.value ? close() : open()
  }

  async function ask(question: string) {
    const q = question.trim()
    if (!q || loading.value) return
    messages.value.push({ id: nextId(), role: 'user', content: q })
    const replyId = nextId()
    messages.value.push({ id: replyId, role: 'assistant', content: '', pending: true })
    loading.value = true
    mood.value = 'think'
    try {
      const r = await aiApi.ask(q)
      const item = messages.value.find((m) => m.id === replyId)
      if (item) {
        item.content = r.answer
        item.citations = r.citations
        item.pending = false
      }
      mood.value = 'ok'
      // 3秒后回到待机表情
      setTimeout(() => {
        if (!loading.value) mood.value = 'idle'
      }, 3000)
    } catch (e: any) {
      const item = messages.value.find((m) => m.id === replyId)
      if (item) {
        item.content = e?.response?.data?.message || '呜哇，鲸鲸的网络线缆好像松了，等下再试一次喵……'
        item.pending = false
      }
      mood.value = 'idle'
    } finally {
      loading.value = false
    }
  }

  function reset() {
    messages.value = []
    mood.value = 'idle'
  }

  return { profile, messages, mood, loading, panelOpen, avatar, loadProfile, open, close, toggle, ask, reset }
})