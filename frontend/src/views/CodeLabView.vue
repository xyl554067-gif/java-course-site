<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import CodeEditor from '@/components/CodeEditor.vue'
import LessonVideoPanel from '@/components/LessonVideoPanel.vue'
import LocalIdePanel from '@/components/LocalIdePanel.vue'
import { courseApi, codeApi, type CodeRuntime, type CodeRunResult, type CodeSnippet, type LearningVideo, type Lesson } from '@/api'
import { errMsg } from '@/api/http'
import { useAuthStore } from '@/stores/auth'

type LabSnippet = CodeSnippet & { stdin?: string | null }

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const lesson = ref<Lesson | null>(null)
const snippets = ref<LabSnippet[]>([])
const videos = ref<LearningVideo[]>([])
const selectedVideo = computed(() => videos.value.find((video) => String(video.id) === route.query.video) ?? videos.value[0])
const videoArea = ref<HTMLElement | null>(null)
const editorArea = ref<HTMLElement | null>(null)
const selected = ref<LabSnippet | null>(null)
const code = ref('')
const stdin = ref('')
const runtime = ref<CodeRuntime | null>(null)
const result = ref<CodeRunResult | null>(null)
const loading = ref(true)
const running = ref(false)
const error = ref('')
const runError = ref('')
const exporting = ref(false)
const exportError = ref('')
const draftUnavailable = ref(false)
const hasLessonPractice = ref(false)
let selectionVersion = 0

const isEdited = computed(() => selected.value !== null
  && (code.value !== selected.value.code || stdin.value !== (selected.value.stdin || '')))
const account = computed(() => auth.user?.id ?? auth.user?.username)
const draftKey = computed(() => {
  if (account.value == null || !lesson.value || !selected.value) return null
  return 'javacourse:lab:' + JSON.stringify([account.value, lesson.value.slug, selected.value.id])
})

function setDraft(nextCode: string, nextStdin: string) {
  code.value = nextCode
  stdin.value = nextStdin
  runError.value = ''
  result.value = null
  selectionVersion++
  if (!draftKey.value) return
  try {
    if (isEdited.value) {
      localStorage.setItem(draftKey.value, JSON.stringify({ code: nextCode, stdin: nextStdin }))
    } else {
      localStorage.removeItem(draftKey.value)
    }
    draftUnavailable.value = false
  } catch {
    draftUnavailable.value = true
  }
}

function syncSelection() {
  const snippet = snippets.value.find((item) => String(item.id) === route.query.snippet) ?? snippets.value[0]
  if (!snippet || selected.value?.id === snippet.id) return
  selected.value = snippet
  selectionVersion++
  result.value = null
  runError.value = ''
  exportError.value = ''
  draftUnavailable.value = false
  code.value = snippet.code || ''
  stdin.value = snippet.stdin || ''
  restoreStoredDraft()
}

function restoreStoredDraft() {
  if (!draftKey.value) return
  try {
    const stored = localStorage.getItem(draftKey.value)
    if (!stored) return
    const draft = JSON.parse(stored)
    if (typeof draft?.code === 'string' && typeof draft?.stdin === 'string') {
      code.value = draft.code
      stdin.value = draft.stdin
    }
  } catch {
    draftUnavailable.value = true
  }
}

function select(snippet: LabSnippet) {
  void router.replace({ query: { ...route.query, snippet: String(snippet.id) } })
}

function selectVideo(id: number) {
  void router.replace({ query: { ...route.query, video: String(id) } })
}

watch(() => route.params.slug, async (slug, _, onCleanup) => {
  if (typeof slug !== 'string') return
  let current = true
  onCleanup(() => { current = false })
  selectionVersion++
  loading.value = true
  error.value = ''
  lesson.value = null
  selected.value = null
  snippets.value = []
  videos.value = []
  hasLessonPractice.value = false
  runtime.value = null
  try {
    const detail = await courseApi.lesson(slug)
    if (!current) return
    const loadedLesson: Lesson = detail.lesson || detail
    lesson.value = loadedLesson
    snippets.value = detail.snippets || []
    videos.value = detail.videos || []
    if (!snippets.value.length && !videos.value.length) {
      error.value = '这节课没有可用的代码示例。'
      return
    }
    if (snippets.value.length) {
      syncSelection()
      void codeApi.runtime().then((value) => {
        if (current) runtime.value = value
      }).catch(() => {})
    }
    void Promise.allSettled([codeApi.exercises(loadedLesson.id), courseApi.qa()]).then(([exercises, questions]) => {
      if (!current) return
      hasLessonPractice.value =
        (exercises.status === 'fulfilled' && exercises.value.some((item) => item.lessonId === loadedLesson.id))
        || (questions.status === 'fulfilled' && questions.value.some((item) => item.lessonId === loadedLesson.id && item.qaType !== 'CODE'))
    })
  } catch (e) {
    if (current) error.value = errMsg(e)
  } finally {
    if (current) loading.value = false
  }
}, { immediate: true })
watch(() => route.query.snippet, syncSelection)
watch(account, restoreStoredDraft)

async function run() {
  if (!runtime.value?.ready || running.value) return
  const version = selectionVersion
  running.value = true
  result.value = null
  runError.value = ''
  try {
    const response = await codeApi.run(code.value, stdin.value)
    if (version === selectionVersion) result.value = response
  } catch (e) {
    if (version === selectionVersion) runError.value = errMsg(e)
  } finally {
    running.value = false
  }
}

async function exportProject() {
  if (exporting.value || !code.value.trim()) return
  exporting.value = true
  exportError.value = ''
  const version = selectionVersion
  try {
    const archive = await codeApi.exportProject(code.value, stdin.value)
    const url = URL.createObjectURL(archive)
    const link = document.createElement('a')
    link.href = url
    link.download = 'java-lesson.zip'
    document.body.append(link)
    link.click()
    link.remove()
    setTimeout(() => URL.revokeObjectURL(url), 1000)
  } catch (e) {
    if (version === selectionVersion) exportError.value = errMsg(e)
  } finally {
    exporting.value = false
  }
}
</script>

<template>
  <div class="container lab-page">
    <div class="lab-top">
      <div>
        <RouterLink :to="{ name: 'lesson', params: { slug: route.params.slug }, query: { tab: 'notes' } }">← 返回笔记</RouterLink>
        <h1>{{ lesson?.title || '代码实验室' }}</h1>
        <p>编辑、运行示例。修改会保存在此浏览器里。</p>
      </div>
      <span class="badge badge--mint">代码实验室</span>
    </div>

    <p v-if="loading || !auth.ready" role="status">正在加载示例…</p>
    <p v-else-if="error" class="card lab-error" role="alert">{{ error }}</p>
    <div v-else-if="selected || selectedVideo" class="lab-layout" :class="{ 'lab-layout--video': selectedVideo }">
      <div class="lab-sidebar" ref="videoArea">
        <LessonVideoPanel v-if="selectedVideo" :videos="videos" :selected="selectedVideo" @select="selectVideo" />
        <button v-if="selectedVideo && selected" type="button" class="btn btn--ghost lab-jump"
          @click="editorArea?.scrollIntoView({ block: 'start' })">跳到练习 ↓</button>
        <aside v-if="selected" class="card lab-list">
          <h2>示例单元</h2>
          <button v-for="snippet in snippets" :key="snippet.id" :class="{ active: snippet.id === selected.id }" :aria-pressed="snippet.id === selected.id" @click="select(snippet)">
            <b>{{ snippet.title }}</b><small>{{ snippet.language || 'java' }}</small>
          </button>
        </aside>
      </div>

      <section v-if="selected" ref="editorArea" class="card lab-editor">
        <button v-if="selectedVideo" type="button" class="btn btn--ghost lab-jump"
          @click="videoArea?.scrollIntoView({ block: 'start' })">返回视频 ↑</button>
        <div class="editor-head">
          <div><span class="badge badge--lilac">{{ selected.language || 'java' }}</span><b>{{ selected.title }}</b></div>
          <div class="lab-actions">
            <button v-if="isEdited" type="button" class="btn btn--ghost" @click="setDraft(selected.code, selected.stdin || '')">恢复原始示例</button>
            <button type="button" class="btn btn--ghost" :disabled="exporting || !code.trim()" @click="exportProject">{{ exporting ? '正在导出…' : '导出 Java 工程' }}</button>
            <button type="button" class="btn btn--primary" :disabled="!runtime?.ready || running" @click="run">{{ running ? '运行中…' : '▶ 运行代码' }}</button>
          </div>
        </div>
        <LocalIdePanel :code="code" :stdin="stdin" />
        <p v-if="draftUnavailable" class="warn" role="status">当前浏览器无法读取或保存草稿。离开前可以导出代码。</p>
        <p v-if="exportError" class="warn" role="alert">{{ exportError }}</p>
        <p v-if="runtime && !runtime.ready" class="warn">{{ runtime.note }}</p>
        <p v-else-if="!runtime" class="warn">代码运行环境暂未就绪。</p>
        <p v-if="selected.explanation" class="explanation">{{ selected.explanation }}</p>
        <CodeEditor :model-value="code" :min-rows="18" @update:model-value="setDraft($event, stdin)" @run="run" />
        <label class="stdin">标准输入（可选）
          <textarea :value="stdin" rows="3" @input="setDraft(code, ($event.target as HTMLTextAreaElement).value)" />
        </label>
        <p v-if="runError" class="warn" role="alert">{{ runError }}</p>
        <div v-if="result" class="result" :class="result.success ? 'pass' : 'fail'" role="status">
          <b>{{ result.success ? '运行成功' : result.message }}</b><span>{{ result.durationMs }} ms</span>
          <p v-if="result.compileMs != null || result.executionMs != null || result.reusedCompilation" class="run-timing">
            <template v-if="result.reusedCompilation">已复用编译结果</template>
            <template v-else-if="result.compileMs != null">编译 {{ result.compileMs }} ms</template>
            <template v-if="result.executionMs != null"> · 执行 {{ result.executionMs }} ms</template>
          </p>
          <pre v-if="result.output || result.stdout || result.stderr">{{ result.output || result.stdout || result.stderr }}</pre>
        </div>
      </section>
      <p v-else class="card lab-error">这节课暂时没有可运行的代码示例。</p>
    </div>

    <section v-if="!loading && auth.ready && !error" class="card lab-exercises">
      <h2>课后习题</h2>
      <RouterLink v-if="hasLessonPractice" class="btn btn--ghost" :to="{ name: 'lesson', params: { slug: route.params.slug }, query: { tab: 'exercises' } }">返回本节习题 →</RouterLink>
      <RouterLink v-else class="btn btn--ghost" to="/exercises">前往代码练习 →</RouterLink>
    </section>
  </div>
</template>

<style scoped>.lab-page{padding:28px 0}.lab-top{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:18px}.lab-top h1{margin:8px 0}.lab-top p,.lab-exercises p{color:var(--c-ink-soft)}.lab-top a{color:var(--c-mint)}.lab-layout{display:grid;grid-template-columns:250px minmax(0,1fr);gap:18px;align-items:start}.lab-list,.lab-editor,.lab-exercises{padding:20px}.lab-list{display:flex;flex-direction:column;gap:8px}.lab-list h2,.lab-exercises h2{margin:0 0 8px}.lab-list button{text-align:left;padding:12px;border:1px solid var(--c-line);border-radius:12px;background:var(--c-paper);color:var(--c-ink);cursor:pointer;display:flex;flex-direction:column;gap:4px}.lab-list button.active{background:var(--c-mint);color:#fff}.lab-list small{opacity:.75}.editor-head{display:flex;justify-content:space-between;align-items:center;gap:10px;margin-bottom:14px}.editor-head>div{display:flex;align-items:center;gap:10px}.warn{padding:10px;background:#fff2d6;border-radius:10px;color:#745619}.explanation{line-height:1.7}.stdin{display:block;margin-top:14px;font-weight:700}.stdin textarea{display:block;width:100%;margin-top:6px;padding:10px;border:1px solid var(--c-line);border-radius:10px;background:var(--c-paper);color:var(--c-ink);font:inherit}.result{margin-top:14px;padding:12px;border-radius:10px}.result.pass{background:#e8f8ef;color:#146543}.result.fail{background:#fff0ee;color:#8f3129}.result span{float:right}.result pre{white-space:pre-wrap;overflow:auto}.lab-exercises{margin-top:18px}.lab-error{padding:20px}@media(max-width:800px){.lab-layout{grid-template-columns:1fr}.lab-list{display:grid;grid-template-columns:1fr 1fr}.lab-list h2{grid-column:1/-1}.editor-head{align-items:flex-start;flex-direction:column}}.lab-actions{flex-wrap:wrap}.run-timing{margin:6px 0 0;font-size:.875rem}
.lab-sidebar { min-width: 0; display: grid; gap: 14px; scroll-margin-top: calc(var(--nav-h) + 10px); }
.lab-editor { min-width: 0; scroll-margin-top: calc(var(--nav-h) + 10px); }
.lab-layout--video { grid-template-columns: minmax(280px, 2fr) minmax(0, 3fr); }
.lab-jump { display: none; }
@media (max-width: 900px) {
  .lab-layout--video { grid-template-columns: minmax(0, 1fr); }
  .lab-jump { display: inline-flex; justify-self: start; margin-bottom: 8px; }
}
</style>
