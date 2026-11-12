import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { AssistantRequestOptions } from '@/api'
import { useAssistantConversation } from './assistantConversation'

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

export const usePetStore = defineStore('pet', () => {
  const state = ref<PetState>('idle')
  const bubbleOpen = ref(false)
  const conversation = useAssistantConversation()
  const animation = computed(() => PET_ANIMATIONS[state.value])
  let replyVersion = 0

  // 清除旧版保存在此浏览器中的助教对话和凭据。
  try {
    localStorage.removeItem('javacourse.pet.history')
    localStorage.removeItem('javacourse.pet.aiConfig')
  } catch { /* 存储可能不可用 */ }

  function setState(next: PetState) {
    state.value = next
  }

  function flash(next: PetState, ms = 2200) {
    state.value = next
    const version = replyVersion
    window.setTimeout(() => {
      if (version === replyVersion && state.value === next) state.value = 'idle'
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

  async function ask(question: string, options?: AssistantRequestOptions) {
    if (!question.trim() || conversation.loading) return
    const version = ++replyVersion
    const pending = conversation.ask(question, options)
    if (conversation.loading) state.value = 'thinking'
    const completed = await pending
    if (version !== replyVersion) return
    if (completed && bubbleOpen.value) flash('talking', 2400)
    else state.value = 'idle'
  }

  function clearHistory() {
    replyVersion++
    conversation.clearHistory()
    state.value = 'idle'
  }

  function reset() {
    replyVersion++
    state.value = 'idle'
    closeBubble()
  }

  return {
    state,
    bubbleOpen,
    animation,
    setState,
    openBubble,
    closeBubble,
    toggleBubble,
    ask,
    reset,
    clearHistory,
  }
})
