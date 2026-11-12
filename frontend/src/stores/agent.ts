import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { aiApi, type AgentProfile, type AssistantRequestOptions } from '@/api'
import { useAssistantConversation, WHALE_GREETING } from './assistantConversation'

export type AgentMood = 'idle' | 'happy' | 'think' | 'ok'

const MOOD_FALLBACK: Record<AgentMood, string> = {
  idle: '/assets/agent/agent-idle.png',
  happy: '/assets/agent/agent-happy.png',
  think: '/assets/agent/agent-think.png',
  ok: '/assets/agent/agent-ok.png',
}
const ASSET_BASE = import.meta.env.BASE_URL || '/'

export const useAgentStore = defineStore('agent', () => {
  const profile = ref<AgentProfile | null>(null)
  const conversation = useAssistantConversation()
  const mood = ref<AgentMood>('idle')
  const panelOpen = ref(false)

  let replyVersion = 0

  const avatar = computed(() => {
    const avatars = profile.value?.avatars
    const index = ['idle', 'happy', 'think', 'ok'].indexOf(mood.value)
    const path = Array.isArray(avatars) ? avatars[index] : avatars?.[mood.value]
    const safePath = typeof path === 'string' && /^\/assets\/agent\/[a-z0-9-]+\.png$/.test(path) ? path : MOOD_FALLBACK[mood.value]
    return ASSET_BASE + safePath.slice(1)
  })

  async function loadProfile() {
    if (profile.value) return
    try {
      profile.value = await aiApi.agent()
    } catch {
      profile.value = {
        key: 'whale',
        name: '鲸鲸',
        title: 'Java 学习助教',
        greeting: WHALE_GREETING,
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

  async function ask(question: string, options?: AssistantRequestOptions) {
    if (!question.trim() || conversation.loading.value) return
    const version = ++replyVersion
    const pending = conversation.ask(question, options)
    if (conversation.loading.value) mood.value = 'think'
    await pending
    if (version !== replyVersion) return
    mood.value = 'ok'
    setTimeout(() => {
      if (version === replyVersion && mood.value === 'ok') mood.value = 'idle'
    }, 3000)
  }

  function clearHistory() {
    replyVersion++
    conversation.clearHistory()
    mood.value = 'idle'
  }

  function reset() {
    clearHistory()
    close()
  }

  return { ...conversation, profile, mood, panelOpen, avatar, loadProfile, open, close, toggle, ask, clearHistory, reset }
})
