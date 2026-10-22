<script setup lang="ts">
/**
 * 悬浮式 AI 助教桌宠 —— 鲸鲸
 *
 * 技术移植说明（源自 dsh-pet 项目的分析结论）：
 *
 * 【渲染技术】dsh-pet 不是 Live2D，也不是序列帧 sprite，而是 **webm 视频（VP9-alpha）**
 *   做逐帧动画，带 alpha 通道。本组件沿用同一套做法：素材是 .webm，靠 <video> 播放。
 *   好处是体积小（单动作 ~400KB）、色彩与原素材完全一致、无需额外的解码库。
 *
 * 【A/B 双缓冲】dsh-pet 用两个 <video> 交替承载（前端 videoARef / videoBRef），
 *   换动画时把新动画装到「后台」那个 video 上，播好后再淡入前台。
 *   原因是直接改同一个 video 的 src 会闪黑/闪白，在桌宠这种小尺寸下非常刺眼。
 *   本组件完整复刻这个机制。
 *
 * 【朝向】dsh-pet 用 `scaleX(-1)` 做左右镜像。本组件不做自动转向（浏览器里没必要），
 *   但保留缩放能力。
 *
 * 【与 dsh-pet 的差异】原项目是 Electron 桌面应用，桌宠是「独立透明置顶窗」，
 *   可以跑出浏览器窗口边界、可以抛掷物理、可以常驻系统托盘。
 *   浏览器里做不到这些，本组件改为：
 *   - 「始终在最上层」→ position: fixed + 最高 z-index（页面上层，非 OS 层级）
 *   - 「拖拽」→ Pointer Events 统一鼠标与触摸；带边界约束与位置持久化
 *   - 「抛掷物理」→ 简化为松手后惯性滑动 + 边界回弹（保留一点手感，成本极低）
 */
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { usePetStore, type PetState } from '@/stores/pet'
import { useAuthStore } from '@/stores/auth'

const pet = usePetStore()
const auth = useAuthStore()
const router = useRouter()

/** 桌宠尺寸（px，指宽度），移动端自动缩小 */
const SIZE = ref(150)
const isMobile = ref(false)
/** 位置（视口坐标，左上角） */
const pos = ref({ x: 0, y: 0 })
/** 拖拽中 */
const dragging = ref(false)
const dragMoved = ref(false)

const videoA = ref<HTMLVideoElement | null>(null)
const videoB = ref<HTMLVideoElement | null>(null)
/** 当前显示的是 A 还是 B */
const front = ref<'a' | 'b'>('a')
/** 已加载成功的动画路径，避免重复 load */
const loadedSrc = ref('')

const input = ref('')
const bubble = ref<HTMLElement | null>(null)
const listEl = ref<HTMLElement | null>(null)

/**
 * 气泡展开方向自适应：桌宠在页面上半部时向上展开会超出视口顶部，
 * 此时改为向下展开。
 */
const bubbleDown = ref(false)

function computeBubbleDir() {
  const h = Math.round(SIZE.value * HEIGHT_RATIO)
  const spaceAbove = pos.value.y - 24
  const spaceBelow = window.innerHeight - (pos.value.y + h) - 24
  bubbleDown.value = spaceAbove < 300 && spaceBelow > spaceAbove
}

const STORAGE_KEY = 'javacourse.pet.pos'

// ------------------------------------------------------------------
// 位置初始化
// ------------------------------------------------------------------
function initSize() {
  isMobile.value = window.innerWidth < 720
  SIZE.value = isMobile.value ? 116 : 156
}

/** 桌宠实际渲染高度（素材比例 4:5） */
const HEIGHT_RATIO = 5 / 4

/** 视口可用区域（扣掉导航栏高度，避免拖到导航下面被盖住） */
function bounds() {
  const pad = 8
  const top = 78
  const h = Math.round(SIZE.value * HEIGHT_RATIO)
  return {
    minX: pad,
    minY: top,
    maxX: window.innerWidth - SIZE.value - pad,
    maxY: window.innerHeight - h - pad,
  }
}

function clampPos() {
  const b = bounds()
  pos.value.x = Math.min(Math.max(pos.value.x, b.minX), Math.max(b.minX, b.maxX))
  pos.value.y = Math.min(Math.max(pos.value.y, b.minY), Math.max(b.minY, b.maxY))
}

function restorePos() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const p = JSON.parse(raw)
      if (typeof p.x === 'number' && typeof p.y === 'number') {
        pos.value = { x: p.x, y: p.y }
        clampPos()
        return
      }
    }
  } catch {
    /* 忽略：本地存储不可用时走默认位置 */
  }
  // 默认：右下角（但抬高一点，避开原悬浮球那个位置）
  const h = Math.round(SIZE.value * HEIGHT_RATIO)
  pos.value = {
    x: window.innerWidth - SIZE.value - 24,
    y: window.innerHeight - h - 118,
  }
  clampPos()
}

function savePos() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(pos.value))
  } catch {
    /* 忽略 */
  }
}

// ------------------------------------------------------------------
// 动画切换（A/B 双缓冲）
// ------------------------------------------------------------------
const frontVideo = computed(() => (front.value === 'a' ? videoA.value : videoB.value))
const backVideo = computed(() => (front.value === 'a' ? videoB.value : videoA.value))

/**
 * 切到新动画：装到后台 video → 等它能播 → 淡入 → 退到后台
 * 若目标动画就是当前动画，直接跳过（避免无意义的重载）
 */
async function switchAnimation(src: string) {
  if (src === loadedSrc.value) return
  const back = backVideo.value
  if (!back) return

  back.src = src
  back.load()
  try {
    await back.play()
  } catch {
    // 自动播放被拦截（浏览器策略）：静音后可再试
    back.muted = true
    try {
      await back.play()
    } catch {
      /* 放弃本次切换，保留原动画 */
      return
    }
  }
  loadedSrc.value = src
  front.value = front.value === 'a' ? 'b' : 'a'
  // 隐藏旧的那一个，避免两层同时可见
  const old = backVideo.value
  if (old) {
    old.style.opacity = '0'
  }
}

watchPetState()

function watchPetState() {
  // 立即切换当前状态对应的动画
  const src = pet.animation
  void switchAnimation(src)
}

// 监听 store 里的状态变化
import { watch } from 'vue'
watch(
  () => pet.state,
  () => {
    void switchAnimation(pet.animation)
  },
)

// ------------------------------------------------------------------
// 拖拽
// ------------------------------------------------------------------
let startPointer = { x: 0, y: 0 }
let startPos = { x: 0, y: 0 }
let rafId = 0
let vel = { x: 0, y: 0 }
let lastMove = { x: 0, y: 0, t: 0 }

function onPointerDown(e: PointerEvent) {
  if (!auth.isLogged) {
    router.push({ name: 'login', query: { redirect: routeFullPath() } })
    return
  }
  ;(e.target as HTMLElement).setPointerCapture?.(e.pointerId)
  dragging.value = true
  dragMoved.value = false
  startPointer = { x: e.clientX, y: e.clientY }
  startPos = { ...pos.value }
  lastMove = { x: e.clientX, y: e.clientY, t: performance.now() }
  vel = { x: 0, y: 0 }
  pet.setState('dragging')
}

function onPointerMove(e: PointerEvent) {
  if (!dragging.value) return
  const dx = e.clientX - startPointer.x
  const dy = e.clientY - startPointer.y
  if (Math.abs(dx) > 4 || Math.abs(dy) > 4) dragMoved.value = true
  pos.value.x = startPos.x + dx
  pos.value.y = startPos.y + dy
  clampPos()

  // 记录瞬时速度（用于松手后的惯性滑动）
  const now = performance.now()
  const dt = now - lastMove.t
  if (dt > 0) {
    vel = { x: ((e.clientX - lastMove.x) / dt) * 16, y: ((e.clientY - lastMove.y) / dt) * 16 }
    lastMove = { x: e.clientX, y: e.clientY, t: now }
  }
}

function onPointerUp() {
  if (!dragging.value) return
  dragging.value = false
  savePos()
  if (!dragMoved.value) {
    // 视为点击：唤出气泡
    computeBubbleDir()
    pet.openBubble()
    void nextTick(() => focusInput())
    return
  }
  pet.setState('idle')
  // 惯性滑动
  glide()
}

/** 松手后的惯性滑动 + 边界回弹（简化版抛掷物理） */
function glide() {
  cancelAnimationFrame(rafId)
  let vx = vel.x
  let vy = vel.y
  if (Math.abs(vx) < 0.4 && Math.abs(vy) < 0.4) return
  const step = () => {
    vx *= 0.94
    vy *= 0.94
    pos.value.x += vx
    pos.value.y += vy
    const b = bounds()
    let bounced = false
    if (pos.value.x < b.minX) { pos.value.x = b.minX; vx = Math.abs(vx) * 0.5; bounced = true }
    if (pos.value.x > b.maxX) { pos.value.x = b.maxX; vx = -Math.abs(vx) * 0.5; bounced = true }
    if (pos.value.y < b.minY) { pos.value.y = b.minY; vy = Math.abs(vy) * 0.5; bounced = true }
    if (pos.value.y > b.maxY) { pos.value.y = b.maxY; vy = -Math.abs(vy) * 0.5; bounced = true }
    if (bounced) savePos()
    if (Math.abs(vx) > 0.4 || Math.abs(vy) > 0.4) {
      rafId = requestAnimationFrame(step)
    } else {
      savePos()
    }
  }
  rafId = requestAnimationFrame(step)
}

// ------------------------------------------------------------------
// 对话气泡
// ------------------------------------------------------------------
function focusInput() {
  const el = document.querySelector<HTMLInputElement>('#pet-ask-input')
  el?.focus()
}

async function submit() {
  const q = input.value.trim()
  if (!q || pet.loading) return
  input.value = ''
  await pet.ask(q)
  await nextTick()
  scrollToBottom()
}

function scrollToBottom() {
  if (listEl.value) listEl.value.scrollTop = listEl.value.scrollHeight
}

function routeFullPath() {
  return window.location.hash.replace(/^#/, '') || '/'
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    void submit()
  }
}

// ------------------------------------------------------------------
// 生命周期
// ------------------------------------------------------------------
function onResize() {
  initSize()
  clampPos()
  savePos()
}

onMounted(() => {
  initSize()
  restorePos()
  window.addEventListener('resize', onResize)
  // 预载待机动画
  void switchAnimation(pet.animation)
})

onUnmounted(() => {
  window.removeEventListener('resize', onResize)
  cancelAnimationFrame(rafId)
  savePos()
})
</script>

<template>
  <!-- 悬浮层：fixed + 最高 z-index，始终盖在页面内容之上 -->
  <div
    class="pet-layer"
    :style="{ left: pos.x + 'px', top: pos.y + 'px', width: SIZE + 'px' }"
  >
    <!-- 对话气泡 -->
    <Transition name="pet-bubble">
      <div
        v-if="pet.bubbleOpen"
        ref="bubble"
        class="pet-bubble"
        :class="{ 'pet-bubble--down': bubbleDown }"
        @click.stop
      >
        <div class="pet-bubble__head">
          <span class="pet-bubble__name">鲸鲸</span>
          <span class="pet-bubble__tag" :class="{ 'is-degraded': pet.degraded }">
            {{ pet.degraded ? '本地兜底' : '大模型' }}
          </span>
          <button class="pet-bubble__close" title="收起" @click="pet.closeBubble()">×</button>
        </div>

        <div ref="listEl" class="pet-bubble__list">
          <div v-if="!pet.messages.length" class="pet-bubble__empty">
            {{ pet.hint }}
          </div>
          <div
            v-for="m in pet.messages"
            :key="m.id"
            class="pet-msg"
            :class="m.role === 'user' ? 'pet-msg--me' : 'pet-msg--ai'"
          >
            <div class="pet-msg__body">
              <template v-if="m.pending">
                <span class="pet-typing"><i /><i /><i /></span>
              </template>
              <template v-else>{{ m.content }}</template>
            </div>
            <div v-if="m.citations && m.citations.length" class="pet-msg__cites">
              <RouterLink
                v-for="c in m.citations"
                :key="c.slug"
                class="pet-cite"
                :to="`/lesson/${c.slug}`"
                @click="pet.closeBubble()"
              >
                {{ c.title }}
              </RouterLink>
            </div>
          </div>
        </div>

        <form class="pet-bubble__input" @submit.prevent="submit">
          <input
            id="pet-ask-input"
            v-model="input"
            type="text"
            placeholder="问点 Java 的事…"
            :disabled="pet.loading"
            @keydown="onKeydown"
          />
          <button type="submit" class="pet-send" :disabled="pet.loading || !input.trim()">
            {{ pet.loading ? '…' : '问' }}
          </button>
        </form>
      </div>
    </Transition>

    <!-- 桌宠本体：双 video A/B 缓冲 -->
    <div
      class="pet-body"
      :class="[
        'pet-body--' + pet.state,
        { 'is-dragging': dragging, 'is-mobile': isMobile },
      ]"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
      @pointercancel="onPointerUp"
      @contextmenu.prevent
    >
      <video
        ref="videoA"
        class="pet-video"
        :class="{ 'is-front': front === 'a' }"
        autoplay
        loop
        muted
        playsinline
        preload="auto"
      />
      <video
        ref="videoB"
        class="pet-video"
        :class="{ 'is-front': front === 'b' }"
        autoplay
        loop
        muted
        playsinline
        preload="auto"
      />

      <!-- 状态气泡标签 -->
      <span class="pet-badge" :class="'pet-badge--' + pet.state">
        {{ pet.state === 'thinking' ? '思考中…' : pet.state === 'talking' ? '喵~' : '' }}
      </span>

      <!-- 未登录提示 -->
      <div v-if="!auth.isLogged" class="pet-login-tip">登录后<br />与我对话</div>
    </div>
  </div>
</template>

<style scoped>
/* ---------- 悬浮层 ---------- */
.pet-layer {
  position: fixed;
  z-index: 9999; /* 盖住导航(40)、抽屉、fab(45) */
  pointer-events: none; /* 只有桌宠本体与气泡可交互 */
  touch-action: none;
}
.pet-layer > * {
  pointer-events: auto;
}

/* ---------- 桌宠本体 ---------- */
.pet-body {
  position: relative;
  width: 100%;
  /* 素材已裁掉左右透明边，为 280:350（4:5）——按此比例撑高，角色才是满的 */
  aspect-ratio: 4 / 5;
  cursor: grab;
  user-select: none;
  -webkit-user-select: none;
  touch-action: none;
  transition: transform .18s cubic-bezier(.34, 1.56, .64, 1);
  filter: drop-shadow(0 6px 10px rgba(45, 53, 97, .28));
}
.pet-body.is-dragging {
  cursor: grabbing;
  transform: scale(1.08) rotate(-3deg);
  z-index: 2;
}
.pet-body--thinking { animation: pet-pulse 1.1s ease-in-out infinite; }
.pet-body--talking { animation: pet-bounce .7s ease-in-out infinite; }
.pet-body--happy { animation: pet-pop .6s ease; }

@keyframes pet-pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.05); }
}
@keyframes pet-bounce {
  0%, 100% { transform: translateY(0) rotate(0); }
  30% { transform: translateY(-6px) rotate(-2deg); }
  60% { transform: translateY(0) rotate(1deg); }
}
@keyframes pet-pop {
  0% { transform: scale(1); }
  40% { transform: scale(1.16) rotate(4deg); }
  100% { transform: scale(1); }
}

/* 双 video：前景 opacity 1，背景 opacity 0 —— 交叉淡入避免闪黑 */
.pet-video {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: contain;
  pointer-events: none;
  opacity: 0;
  transition: opacity .18s ease;
}
.pet-video.is-front {
  opacity: 1;
}

.pet-badge {
  position: absolute;
  top: -6px;
  left: 50%;
  transform: translateX(-50%);
  padding: 2px 10px;
  background: var(--c-sun);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-full);
  font-family: var(--font-round);
  font-size: 12px;
  font-weight: 800;
  color: var(--c-ink);
  white-space: nowrap;
  box-shadow: 2px 2px 0 var(--c-line);
  opacity: 0;
  transition: opacity .2s;
  pointer-events: none;
}
.pet-badge--thinking,
.pet-badge--talking {
  opacity: 1;
}

.pet-login-tip {
  position: absolute;
  bottom: -4px;
  left: 50%;
  transform: translateX(-50%);
  padding: 3px 10px;
  background: var(--c-paper);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-full);
  font-size: 11px;
  font-weight: 700;
  line-height: 1.35;
  text-align: center;
  color: var(--c-ink-soft);
  box-shadow: 2px 2px 0 var(--c-line);
  white-space: nowrap;
  pointer-events: none;
}

/* ---------- 对话气泡 ---------- */
.pet-bubble {
  position: absolute;
  bottom: calc(100% + 12px);
  right: 0;
  width: min(320px, calc(100vw - 32px));
  background: var(--c-paper);
  border: var(--bw-base) solid var(--c-line);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-md);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  max-height: min(420px, 60vh);
}
.pet-bubble::after {
  /* 小尾巴指向桌宠 */
  content: '';
  position: absolute;
  bottom: -13px;
  right: 26px;
  width: 20px;
  height: 20px;
  background: var(--c-paper);
  border-right: var(--bw-base) solid var(--c-line);
  border-bottom: var(--bw-base) solid var(--c-line);
  transform: rotate(45deg);
}

/* 向下展开（桌宠在页面上半部时，避免超出视口顶部） */
.pet-bubble--down {
  bottom: auto;
  top: calc(100% + 12px);
}
.pet-bubble--down::after {
  bottom: auto;
  top: -13px;
  border-right: none;
  border-bottom: none;
  border-left: var(--bw-base) solid var(--c-line);
  border-top: var(--bw-base) solid var(--c-line);
}

.pet-bubble__head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  background: var(--c-mint);
  border-bottom: var(--bw-thin) solid var(--c-line);
}
.pet-bubble__name {
  font-family: var(--font-round);
  font-size: 16px;
  font-weight: 800;
  color: #fff;
  text-shadow: 1px 1px 0 rgba(45, 53, 97, .3);
}
.pet-bubble__tag {
  padding: 1px 8px;
  background: var(--c-sun);
  border: 2px solid var(--c-line);
  border-radius: var(--radius-full);
  font-size: 11px;
  font-weight: 800;
  color: var(--c-ink);
}
.pet-bubble__tag.is-degraded {
  background: var(--c-peach);
}
.pet-bubble__close {
  margin-left: auto;
  width: 24px;
  height: 24px;
  display: grid;
  place-items: center;
  background: transparent;
  border: 2px solid var(--c-line);
  border-radius: 50%;
  font-size: 16px;
  font-weight: 800;
  line-height: 1;
  color: var(--c-ink);
  cursor: pointer;
}
.pet-bubble__close:hover { background: var(--c-sun); }

.pet-bubble__list {
  flex: 1;
  overflow-y: auto;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  min-height: 90px;
}
.pet-bubble__empty {
  color: var(--c-ink-faint);
  font-size: 13px;
  text-align: center;
  padding: 18px 0;
}

.pet-msg {
  max-width: 88%;
  font-size: 13px;
  line-height: 1.65;
}
.pet-msg--me {
  align-self: flex-end;
}
.pet-msg--ai {
  align-self: flex-start;
}
.pet-msg__body {
  padding: 8px 11px;
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-md);
  white-space: pre-wrap;
  word-break: break-word;
  box-shadow: 2px 2px 0 var(--c-line);
}
.pet-msg--me .pet-msg__body {
  background: var(--c-sky);
  border-radius: var(--radius-md) var(--radius-md) 4px var(--radius-md);
}
.pet-msg--ai .pet-msg__body {
  background: var(--c-cream-deep);
  border-radius: var(--radius-md) var(--radius-md) var(--radius-md) 4px;
}
.pet-msg__cites {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  margin-top: 5px;
}
.pet-cite {
  padding: 2px 8px;
  background: var(--c-mint);
  border: 2px solid var(--c-line);
  border-radius: var(--radius-full);
  font-size: 11px;
  font-weight: 700;
  color: var(--c-ink);
  text-decoration: none;
}
.pet-cite:hover { background: var(--c-sun); }

.pet-typing {
  display: inline-flex;
  gap: 4px;
  align-items: center;
  height: 16px;
}
.pet-typing i {
  width: 6px;
  height: 6px;
  background: var(--c-ink-soft);
  border-radius: 50%;
  animation: pet-dot 1.1s infinite ease-in-out;
}
.pet-typing i:nth-child(2) { animation-delay: .18s; }
.pet-typing i:nth-child(3) { animation-delay: .36s; }
@keyframes pet-dot {
  0%, 60%, 100% { transform: translateY(0); opacity: .45; }
  30% { transform: translateY(-5px); opacity: 1; }
}

.pet-bubble__input {
  display: flex;
  gap: 6px;
  padding: 8px;
  border-top: var(--bw-thin) solid var(--c-line);
  background: var(--c-cream);
}
.pet-bubble__input input {
  flex: 1;
  min-width: 0;
  padding: 8px 11px;
  font-family: var(--font-body);
  font-size: 13px;
  color: var(--c-ink);
  background: var(--c-paper);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-full);
  outline: none;
}
.pet-bubble__input input:focus {
  border-color: var(--c-mint-deep);
  box-shadow: 0 0 0 3px rgba(78, 205, 196, .28);
}
.pet-send {
  padding: 0 15px;
  background: var(--c-coral);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-full);
  font-family: var(--font-round);
  font-size: 14px;
  font-weight: 800;
  color: #fff;
  cursor: pointer;
  box-shadow: 2px 2px 0 var(--c-line);
}
.pet-send:disabled {
  opacity: .5;
  cursor: not-allowed;
}
.pet-send:not(:disabled):hover { background: var(--c-coral-deep); }

/* ---------- 气泡进出动画 ---------- */
.pet-bubble-enter-active,
.pet-bubble-leave-active {
  transition: opacity .2s ease, transform .2s cubic-bezier(.34, 1.56, .64, 1);
}
.pet-bubble-enter-from,
.pet-bubble-leave-to {
  opacity: 0;
  transform: translateY(10px) scale(.94);
}

/* ---------- 移动端适配 ---------- */
@media (max-width: 720px) {
  .pet-bubble,
  .pet-bubble--down {
    position: fixed;
    left: 12px;
    right: 12px;
    bottom: 12px;
    top: auto;
    width: auto;
    max-height: 56vh;
  }
  .pet-bubble::after,
  .pet-bubble--down::after { display: none; }
  .pet-body { filter: drop-shadow(0 4px 8px rgba(45, 53, 97, .24)); }
  .pet-msg { max-width: 92%; }
}

/* 尊重系统的「减少动态效果」偏好 */
@media (prefers-reduced-motion: reduce) {
  .pet-body,
  .pet-msg__body,
  .pet-typing i { animation: none !important; }
  .pet-video { transition: none; }
}
</style>
