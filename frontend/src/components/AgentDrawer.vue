<script setup lang="ts">
import { ref, nextTick, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAgentStore } from '@/stores/agent'
import { errMsg } from '@/api/http'

const agent = useAgentStore()
const router = useRouter()
const input = ref('')
const listEl = ref<HTMLElement | null>(null)

const QUICK = [
  'int 和 long 有什么区别？',
  '线程池参数怎么设置？',
  'JVM 内存结构是怎样的？',
  'HashMap 为什么线程不安全？',
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
  const q = input.value.trim()
  if (!q) return
  input.value = ''
  void agent.ask(q).then(scrollDown)
}

function askQuick(q: string) {
  void agent.ask(q).then(scrollDown)
}

/** 把回答里的 [查看该课时](/lesson/xxx) 转成可点击跳转 */
function onAnswerClick(e: MouseEvent) {
  const target = e.target as HTMLElement
  const a = target.closest('a[data-slug]') as HTMLElement | null
  if (!a) return
  e.preventDefault()
  const slug = a.dataset.slug
  agent.close()
  router.push(`/lesson/${slug}`)
}

function cycleMeme() {
  memeIdx.value = (memeIdx.value + 1) % memes.length
  window.setTimeout(() => (memeIdx.value = -1), 2200)
}

watch(
  () => agent.messages.length,
  () => void scrollDown(),
)
watch(
  () => agent.panelOpen,
  (v) => {
    if (v) {
      void agent.loadProfile()
      void scrollDown()
    }
  },
)

// 按需加载：仅在抽屉打开时拉取助手资料。
// 挂载即拉会在静态部署（GitHub Pages 无后端）时产生无意义的 404 请求。
onMounted(() => {
  if (agent.panelOpen) void agent.loadProfile()
})
</script>

<template>
  <!-- 遮罩 -->
  <Transition name="mask">
    <div v-if="agent.panelOpen" class="drawer__mask" @click="agent.close()" />
  </Transition>

  <!-- 抽屉 -->
  <Transition name="slide">
    <aside v-if="agent.panelOpen" class="drawer card">
      <!-- 头部 -->
      <header class="drawer__head">
        <div class="drawer__avatar" @click="cycleMeme">
          <img :src="agent.avatar" alt="鲸鲸" class="drawer__avatar-img" :class="{ 'is-think': agent.loading }" />
          <span v-if="agent.loading" class="drawer__thinking">…</span>
          <img v-if="memeIdx >= 0" :src="memes[memeIdx]" class="drawer__meme" alt="表情包" />
        </div>
        <div class="drawer__meta">
          <h3 class="drawer__name title-round">{{ agent.profile?.name || '鲸鲸' }}</h3>
          <span class="drawer__role">{{ agent.profile?.title || 'Ciallo~ 课程助教' }}</span>
          <span class="drawer__status">
            <i class="dot" /> {{ agent.loading ? '正在思考…' : '在线陪你学' }}
          </span>
        </div>
        <button class="drawer__close" @click="agent.close()" title="收起">×</button>
      </header>

      <!-- 消息流 -->
      <div ref="listEl" class="drawer__body">
        <!-- 欢迎语 -->
        <div class="msg msg--bot">
          <img :src="agent.avatar" class="msg__avatar" alt="鲸鲸" />
          <div class="msg__bubble">
            {{ agent.profile?.greeting || 'Ciallo~ 我是鲸鲸！' }}
          </div>
        </div>

        <!-- 消息列表 -->
        <div v-for="m in agent.messages" :key="m.id" class="msg" :class="m.role === 'user' ? 'msg--me' : 'msg--bot'">
          <img v-if="m.role === 'assistant'" :src="agent.avatar" class="msg__avatar" alt="鲸鲸" />
          <div class="msg__col">
            <div class="msg__bubble" :class="{ 'is-pending': m.pending }" @click="onAnswerClick">
              <template v-if="m.pending">
                <span class="typing"><i /><i /><i /></span>
              </template>
              <template v-else>
                <div class="md" v-html="renderMarkdown(m.content)" />
              </template>
            </div>
            <!-- 引用来源 -->
            <div v-if="m.citations?.length" class="cites">
              <span class="cites__label">引用自</span>
              <a
                v-for="(c, i) in m.citations"
                :key="i"
                class="badge badge--mint cites__item"
                :data-slug="c.slug"
                @click.stop="onAnswerClick"
              >
                {{ c.title }}
              </a>
            </div>
          </div>
        </div>
      </div>

      <!-- 快捷提问 -->
      <div class="drawer__quick">
        <button v-for="q in QUICK" :key="q" class="quick-chip" @click="askQuick(q)">{{ q }}</button>
      </div>

      <!-- 输入区 -->
      <footer class="drawer__foot">
        <input
          v-model="input"
          class="input"
          placeholder="问鲸鲸一个问题…（Enter 发送）"
          @keyup.enter="send"
        />
        <button class="btn btn--primary" :disabled="agent.loading" @click="send">发送</button>
      </footer>
    </aside>
  </Transition>
</template>

<script lang="ts">
/** 极简 Markdown 渲染：粗体、行内代码、引用、列表、课时链接 */
function renderMarkdown(src: string): string {
  const esc = (s: string) =>
    s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  let out = esc(src || '')
  out = out.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  out = out.replace(/`([^`]+)`/g, '<code>$1</code>')
  out = out.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, t, u) => {
    const slug = String(u).split('/lesson/')[1] || ''
    return slug ? `<a href="#" data-slug="${slug}">${t}</a>` : `<span>${t}</span>`
  })
  // 引用块
  out = out.replace(/^&gt;\s?(.*)$/gm, '<blockquote>$1</blockquote>')
  out = out.replace(/<\/blockquote>\n<blockquote>/g, '\n</blockquote>\n<blockquote>')
  // 列表
  out = out.replace(/^(\d+)\.\s+(.*)$/gm, '<li>$2</li>')
  out = out.replace(/(<li>[\s\S]*?<\/li>)(?!\s*<li>)/g, '<ol>$1</ol>')
  return out
}

export default { methods: { renderMarkdown } }
</script>

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

/* 消息流 */
.drawer__body {
  flex: 1;
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
.msg__col { max-width: 78%; }
.msg__bubble {
  padding: 11px 15px;
  font-size: 14px;
  line-height: 1.7;
  background: var(--c-paper);
  border: var(--bw-base) solid var(--c-line);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  word-break: break-word;
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

/* 回答里的 Markdown */
.md :deep(strong) { color: var(--c-coral-deep); }
.md :deep(code) {
  padding: 1px 6px;
  font-family: var(--font-mono);
  font-size: 13px;
  background: var(--c-cream-deep);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: 6px;
}
.md :deep(blockquote) {
  margin: 8px 0;
  padding: 8px 12px;
  background: var(--c-cream-deep);
  border-left: 5px solid var(--c-mint);
  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  color: var(--c-ink-soft);
}
.md :deep(ol) { margin: 8px 0; padding-left: 22px; }
.md :deep(li) { margin-bottom: 4px; }
.md :deep(a) {
  display: inline-block;
  margin-top: 4px;
  color: var(--c-lilac-deep);
  font-weight: 700;
  cursor: pointer;
}
.md :deep(a:hover) { text-decoration: underline; }

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
  display: flex;
  gap: 8px;
  padding: 14px;
  background: var(--c-paper);
  border-top: var(--bw-base) solid var(--c-line);
}

.slide-enter-active, .slide-leave-active { transition: transform .28s cubic-bezier(.34,1.4,.64,1); }
.slide-enter-from, .slide-leave-to { transform: translateX(100%); }
.mask-enter-active, .mask-leave-active { transition: opacity .2s; }
.mask-enter-from, .mask-leave-to { opacity: 0; }
</style>