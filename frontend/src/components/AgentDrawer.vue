<script setup lang="ts">
import { ref, nextTick, watch, onMounted, onUnmounted } from 'vue'
import { RouterLink } from 'vue-router'
import { useAgentStore } from '@/stores/agent'
import AssistantOptions from '@/components/AssistantOptions.vue'
import AssistantAnswer from '@/components/AssistantAnswer.vue'
import { MAX_QUESTION_LENGTH, useAssistantConversation, useAssistantRequestOptions, WHALE_GREETING, WHALE_INTRO_QUESTION, WHALE_LOCAL_NOTICE, WHALE_PRIVACY_NOTICE } from '@/stores/assistantConversation'

const agent = useAgentStore()
const { localOnly, includeLesson, lessonSlug, requestOptions } = useAssistantRequestOptions()
const conversation = useAssistantConversation()
let opener: HTMLElement | null = null
const listEl = ref<HTMLElement | null>(null)
const inputEl = ref<HTMLInputElement | null>(null)

/**
 * 离场动画期间元素仍然留在 DOM 里：遮罩会继续拦截整页点击，抽屉仍能被 Tab 聚焦。
 * 这里在离场开始时统一把元素置为 inert（不可点击、不可聚焦、对读屏不可见）。
 */
function lockOnLeave(el: Element) {
  el.setAttribute('inert', '')
  el.setAttribute('aria-hidden', 'true')
}

const QUICK = [
  WHALE_INTRO_QUESTION,
  '你能帮我什么？',
  'int 和 long 有什么区别？',
  '线程池参数怎么设置？',
]

const memes = [
  '/assets/agent/meme-ciallo.png',
  '/assets/agent/meme-amazing.png',
  '/assets/agent/meme-oh.png',
  '/assets/agent/meme-cute.png',
]
const memeIdx = ref(-1)

async function scrollDown() {
  await nextTick()
  if (listEl.value) listEl.value.scrollTop = listEl.value.scrollHeight
}

function send() {
  const q = conversation.draft.trim()
  if (!q || conversation.loading) return
  conversation.draft = ''
  void agent.ask(q, requestOptions())
}

function askQuick(q: string) {
  void agent.ask(q, requestOptions())
}

function clearConversation() {
  agent.clearHistory()
  inputEl.value?.focus()
}

function cycleMeme() {
  memeIdx.value = (memeIdx.value + 1) % memes.length
  window.setTimeout(() => (memeIdx.value = -1), 2200)
}

watch(
  () => [conversation.messages.length, conversation.loading, agent.expanded],
  () => void scrollDown(),
)
watch(
  () => agent.panelOpen,
  (v) => {
    if (v) {
      opener = document.activeElement instanceof HTMLElement ? document.activeElement : null
      void scrollDown()
      // 打开后把焦点移进输入框，键盘用户可以直接提问
      void nextTick(() => inputEl.value?.focus())
    } else {
      void nextTick(() => {
        if (opener?.isConnected && !opener.closest('[inert]')) opener.focus()
        else document.querySelector<HTMLElement>('.fab, .pet-body[tabindex="0"]')?.focus()
      })
    }
  },
)

// Esc 关闭抽屉，避免键盘用户被关在抽屉里
function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape' && agent.panelOpen) agent.close()
}
onMounted(() => window.addEventListener('keydown', onKeydown))
onUnmounted(() => window.removeEventListener('keydown', onKeydown))
</script>

<template>
  <!-- 遮罩 -->
  <Transition name="mask" @before-leave="lockOnLeave">
    <div v-if="agent.panelOpen" class="drawer__mask" @click="agent.close()" />
  </Transition>

  <!-- 抽屉 -->
  <Transition name="slide" @before-leave="lockOnLeave">
    <aside v-if="agent.panelOpen" id="agent-drawer" class="drawer card" :class="{ 'drawer--expanded': agent.expanded }" role="dialog" aria-modal="true" aria-label="鲸鲸助教">
      <!-- 头部 -->
      <header class="drawer__head">
        <div class="drawer__avatar" @click="cycleMeme">
          <img :src="agent.avatar" alt="鲸鲸" class="drawer__avatar-img" :class="{ 'is-think': conversation.loading }" />
          <span v-if="conversation.loading" class="drawer__thinking">…</span>
          <img v-if="memeIdx >= 0" :src="memes[memeIdx]" class="drawer__meme" alt="表情包" />
        </div>
        <div class="drawer__meta">
          <h3 class="drawer__name title-round">{{ agent.profile?.name || '鲸鲸' }}</h3>
          <span class="drawer__role">Java 学习助教</span>
          <span class="drawer__status">
            <i v-if="conversation.loading" class="dot" /> {{ conversation.loading ? '正在思考…' : '概念讲解 · 代码排错 · 练习提示' }}
          </span>
        </div>
        <button type="button" class="drawer__size" :aria-pressed="agent.expanded" @click="agent.expanded = !agent.expanded">
          {{ agent.expanded ? '还原' : '放大' }}
        </button>
        <button v-if="conversation.messages.length || conversation.draft" class="drawer__clear" type="button" @click="clearConversation">清空</button>
        <button class="drawer__close" type="button" @click="agent.close()" title="收起" aria-label="收起">×</button>
      </header>

      <!-- 消息流 -->
      <div ref="listEl" class="drawer__body" role="log" aria-label="助教对话">
        <!-- 欢迎语 -->
        <div class="msg msg--bot">
          <img :src="agent.avatar" class="msg__avatar" alt="鲸鲸" />
          <div class="msg__bubble">
            {{ WHALE_GREETING }}
          </div>
        </div>

        <!-- 消息列表 -->
        <div v-for="m in conversation.messages" :key="m.id" class="msg" :class="m.role === 'user' ? 'msg--me' : 'msg--bot'">
          <img v-if="m.role === 'assistant'" :src="agent.avatar" class="msg__avatar" alt="鲸鲸" />
          <div class="msg__col">
            <div class="msg__bubble" :class="{ 'is-pending': m.pending }">
              <template v-if="m.pending">
                <span class="typing"><i /><i /><i /></span>
              </template>
              <template v-else-if="m.role === 'assistant'">
                <AssistantAnswer :content="m.content" @navigate="agent.close()" />
              </template>
              <template v-else>{{ m.content }}</template>
            </div>
            <!-- 引用来源 -->
            <div v-if="m.citations?.length" class="cites">
              <span class="cites__label">引用自</span>
              <RouterLink
                v-for="(c, i) in m.citations"
                :key="i"
                class="badge badge--mint cites__item"
                :to="`/lesson/${c.slug}`"
                @click="agent.close()"
              >
                {{ c.title }}
              </RouterLink>
            </div>
          </div>
        </div>
      </div>

      <!-- 快捷提问 -->
      <div class="drawer__quick">
        <button v-for="q in QUICK" :key="q" class="quick-chip" :disabled="conversation.loading" @click="askQuick(q)">{{ q }}</button>
      </div>

      <!-- 输入区 -->
      <footer class="drawer__foot">
        <AssistantOptions v-model:local-only="localOnly" v-model:include-lesson="includeLesson" :can-include-lesson="!!lessonSlug" />
        <p id="drawer-privacy" class="drawer__privacy">{{ localOnly ? WHALE_LOCAL_NOTICE : WHALE_PRIVACY_NOTICE }}</p>
        <form class="drawer__compose" @submit.prevent="send">
          <input
            ref="inputEl"
            v-model="conversation.draft"
            class="input"
            placeholder="问鲸鲸一个 Java 问题…"
            aria-label="要问鲸鲸的问题"
            aria-describedby="drawer-privacy"
            :maxlength="MAX_QUESTION_LENGTH"
            autocomplete="off"
            spellcheck="false"
          />
          <button class="btn btn--primary" type="submit" :disabled="conversation.loading || !conversation.draft.trim()">发送</button>
        </form>
      </footer>
    </aside>
  </Transition>
</template>

<style scoped>
.drawer__mask {
  position: fixed;
  inset: 0;
  background: rgba(45, 53, 97, .28);
  backdrop-filter: blur(2px);
  z-index: 90;
}
.drawer {
  position: fixed;
  top: 0; right: 0;
  width: 430px;
  max-width: 94vw;
  height: 100%;
  display: flex;
  flex-direction: column;
  border-radius: 0;
  border-right: none;
  box-shadow: -8px 0 0 rgba(45, 53, 97, .12);
  z-index: 91;
  overflow: hidden;
}

/* 头部 */
.drawer--expanded { width: min(900px, 94vw); }

.drawer__head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px 18px;
  background: var(--c-mint);
  border-bottom: var(--bw-base) solid var(--c-line);
}
.drawer__avatar { position: relative; width: 58px; height: 58px; cursor: pointer; flex-shrink: 0; }
.drawer__avatar-img {
  width: 100%; height: 100%;
  background: var(--c-paper);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: 50%;
}
.drawer__avatar-img.is-think { animation: wiggle .9s ease-in-out infinite; }
.drawer__thinking {
  position: absolute; inset: 0;
  display: grid; place-items: center;
  font-size: 24px; font-weight: 800; color: var(--c-coral);
}
.drawer__meme {
  position: absolute;
  left: 50%; top: 50%;
  width: 130px;
  transform: translate(-50%, -50%) rotate(-8deg);
  animation: pop-in .3s both;
  pointer-events: none;
}
.drawer__meta { flex: 1; min-width: 0; }
.drawer__name { margin: 0; font-size: 19px; color: #fff; }
.drawer__role { display: block; font-size: 12px; color: rgba(255,255,255,.92); }
.drawer__status { display: flex; align-items: center; gap: 5px; font-size: 12px; color: rgba(255,255,255,.92); }
.drawer__status .dot {
  width: 8px; height: 8px;
  background: #fff;
  border-radius: 50%;
  animation: blink 1.4s ease-in-out infinite;
}
.drawer__close {
  width: 34px; height: 34px;
  font-size: 22px; line-height: 1;
  color: var(--c-ink);
  background: var(--c-paper);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: 50%;
  cursor: pointer;
}
.drawer__close:hover { background: var(--c-coral); color: #fff; }
.drawer__size, .drawer__clear {
  border: 0;
  background: transparent;
  color: var(--c-ink);
  font: inherit;
  font-size: 12px;
  cursor: pointer;
}

/* 消息流 */
.drawer__body {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 18px;
  background: var(--c-cream);
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.msg { display: flex; gap: 10px; align-items: flex-start; }
.msg--me { flex-direction: row-reverse; }
.msg__avatar { width: 38px; height: 38px; border: var(--bw-thin) solid var(--c-line); border-radius: 50%; background: #fff; flex-shrink: 0; }
.msg__col { max-width: 86%; min-width: 0; }
.msg__bubble {
  padding: 11px 15px;
  font-size: 14px;
  line-height: 1.7;
  background: var(--c-paper);
  border: var(--bw-base) solid var(--c-line);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  word-break: break-word;
  white-space: pre-wrap;
}
.msg--me .msg__bubble { background: var(--c-sun); }
.msg__bubble.is-pending { padding: 16px; }

.typing { display: inline-flex; gap: 5px; }
.typing i {
  width: 8px; height: 8px;
  background: var(--c-ink-soft);
  border-radius: 50%;
  animation: float-y .9s ease-in-out infinite;
}
.typing i:nth-child(2) { animation-delay: .15s; }
.typing i:nth-child(3) { animation-delay: .3s; }

/* 引用 */
.cites { margin-top: 6px; display: flex; flex-wrap: wrap; gap: 5px; align-items: center; }
.cites__label { font-size: 12px; color: var(--c-ink-faint); }
.cites__item { cursor: pointer; font-size: 11px; }
.cites__item:hover { background: var(--c-sun); color: var(--c-ink); }

/* 快捷提问 */
.drawer__quick {
  display: flex;
  gap: 7px;
  padding: 10px 14px;
  overflow-x: auto;
  background: var(--c-cream-deep);
  border-top: var(--bw-thin) dashed var(--c-ink-faint);
}
.quick-chip {
  flex-shrink: 0;
  padding: 5px 12px;
  font-family: var(--font-body);
  font-size: 12px;
  color: var(--c-ink);
  background: var(--c-paper);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-full);
  cursor: pointer;
  white-space: nowrap;
}
.quick-chip:hover { background: var(--c-lilac); color: #fff; }

/* 输入 */
.drawer__foot {
  padding: 14px;
  background: var(--c-paper);
  border-top: var(--bw-base) solid var(--c-line);
}
.drawer__privacy { margin: 0 0 8px; color: var(--c-ink-soft); font-size: 12px; line-height: 1.5; }
.drawer__compose { display: flex; gap: 8px; }
@media (max-width: 600px) {
  .drawer--expanded { width: 100vw; max-width: 100vw; }
  .drawer__head { gap: 8px; padding: 10px; }
  .drawer__avatar { width: 40px; height: 40px; }
  .drawer__size, .drawer__clear { white-space: nowrap; }
}
.drawer__compose .input { min-width: 0; flex: 1; }

.slide-enter-active, .slide-leave-active { transition: transform .28s cubic-bezier(.34,1.4,.64,1); }
.slide-enter-from, .slide-leave-to { transform: translateX(100%); }
.mask-enter-active, .mask-leave-active { transition: opacity .2s; }
.mask-enter-from, .mask-leave-to { opacity: 0; }

/* 离场过渡期间元素已不可见，必须停止拦截点击与焦点（inert 的兜底） */
.slide-leave-active, .mask-leave-active { pointer-events: none; }
</style>
