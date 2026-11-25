<script setup lang="ts">
/**
 * 课后习题页
 *
 * 完整闭环：读题 → 在编辑器里写代码 → 运行（看输出/编译错误）→ 提交（自动判题）→ 看历史提交。
 *
 * 判题由后端真实执行 JDK 完成（POST /code/submit），前端只负责展示明细：
 * 哪条用例过了、哪条没过、期望什么、实际什么。
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import CodeEditor from '@/components/CodeEditor.vue'
import CodeRunTiming from '@/components/CodeRunTiming.vue'
import PracticeTopics from '@/components/PracticeTopics.vue'
import { codeApi, courseApi, type CodeExercise, type CodeRuntime, type JudgeResult, type CodeRunResult, type CodeSubmission, type QaLessonOption } from '@/api'
import { errMsg } from '@/api/http'
import { resourceNoteForExercise } from '@/content/course-resources'
import { matchesPracticeQuery, practiceLevel, practiceLevelLabel, practiceLevels, practiceTopics } from '@/content/practice-catalog'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const exercises = ref<CodeExercise[]>([])
const lessons = ref<QaLessonOption[]>([])
const runtime = ref<CodeRuntime | null>(null)
const checkingRuntime = ref(false)
const runtimeError = ref('')
const current = ref<CodeExercise | null>(null)
const code = ref('')
const stdin = ref('')
const runResult = ref<CodeRunResult | null>(null)
const judgeResult = ref<JudgeResult | null>(null)
const submissions = ref<CodeSubmission[]>([])
const loading = ref(true)
const running = ref(false)
const submitting = ref(false)
const error = ref('')
const showHint = ref(false)
const loadError = ref('')
const draftUnavailable = ref(false)
const editorRef = ref<InstanceType<typeof CodeEditor> | null>(null)
let selectionVersion = 0

const ready = computed(() => runtime.value?.ready === true)
const account = computed(() => auth.user?.id ?? auth.user?.username)
const draftKey = computed(() => current.value && account.value != null
  ? 'javacourse:exercise:' + JSON.stringify([account.value, current.value.id])
  : null)
const hasEdits = computed(() => current.value != null && (code.value !== (current.value.starterCode || '') || stdin.value !== ''))
const draftInput = computed({
  get: () => stdin.value,
  set: (value: string) => {
    stdin.value = value
    saveDraft()
  },
})
const resourceNote = computed(() => resourceNoteForExercise(current.value?.slug))
const slug = computed(() => typeof route.params.slug === 'string' ? route.params.slug : '')
const topicId = computed(() => typeof route.query.topic === 'string' ? route.query.topic : '')
const resourceOnly = computed(() => route.query.resource === 'all')
const keyword = computed({
  get: () => typeof route.query.q === 'string' ? route.query.q : '',
  set: (value: string) => setFilter('q', value),
})
const difficulty = computed({
  get: () => {
    const level = typeof route.query.difficulty === 'string' ? practiceLevel(route.query.difficulty) : ''
    return practiceLevels.some(option => option.id === level) ? level : ''
  },
  set: (value: string) => setFilter('difficulty', value),
})
const topics = computed(() => practiceTopics(exercises.value, lessons.value))
const topic = computed(() => topics.value.find(group => group.id === topicId.value))
const filtersActive = computed(() => Boolean(keyword.value.trim() || difficulty.value || resourceOnly.value))
const shownExercises = computed(() => (topicId.value ? topic.value?.items ?? [] : exercises.value).filter(exercise =>
  (!resourceOnly.value || resourceNoteForExercise(exercise.slug))
  && (!difficulty.value || difficulty.value === practiceLevel(exercise.difficulty))
  && matchesPracticeQuery(keyword.value, exercise.title, exercise.lessonTitle, exercise.description),
))

function setFilter(name: 'topic' | 'resource' | 'q' | 'difficulty', value: string) {
  void router.replace({ query: { ...route.query, [name]: value || undefined } })
}

function clearFilters(overview = false) {
  void router.replace({
    query: { ...route.query, q: undefined, difficulty: undefined, resource: undefined, topic: overview ? undefined : route.query.topic },
  })
}

async function loadRuntime() {
  if (checkingRuntime.value) return
  checkingRuntime.value = true
  runtimeError.value = ''
  try {
    runtime.value = await codeApi.runtime()
  } catch (e) {
    runtime.value = null
    runtimeError.value = errMsg(e)
  } finally {
    checkingRuntime.value = false
  }
}

const statusMeta = computed(() => {
  const s = judgeResult.value?.status
  if (!s) return null
  switch (s) {
    case 'PASSED':
      return { cls: 'is-pass', label: '判题通过', icon: '✓' }
    case 'FAILED':
      return { cls: 'is-fail', label: '未通过', icon: '✗' }
    case 'COMPILE_ERROR':
      return { cls: 'is-err', label: '编译失败', icon: '⚠' }
    case 'RUNTIME_ERROR':
      return { cls: 'is-err', label: '运行异常', icon: '⚠' }
    case 'TIMEOUT':
      return { cls: 'is-err', label: '执行超时', icon: '⏱' }
    default:
      return { cls: 'is-err', label: s, icon: '⚠' }
  }
})

/** 从后端下发的测试用例 JSON 里取出用例名（仅展示名称，不泄露期望值） */
const caseNames = computed(() => {
  const raw = current.value?.testCases
  if (!raw) return [] as string[]
  try {
    const arr = JSON.parse(raw)
    return Array.isArray(arr) ? arr.map((c: any) => String(c.name ?? '用例')) : []
  } catch {
    return []
  }
})

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    const [list, lessonList] = await Promise.all([codeApi.exercises(), courseApi.qaLessons()])
    exercises.value = list
    lessons.value = lessonList
    if (slug.value) selectBySlug(slug.value)
  } catch (e) {
    loadError.value = errMsg(e)
  } finally {
    loading.value = false
  }
}

function selectBySlug(slug: string) {
  const exercise = exercises.value.find((item) => item.slug === slug)
  if (!exercise) {
    selectionVersion++
    current.value = null
    error.value = '未找到这道代码练习，请从列表选择其他练习。'
  } else if (exercise.id !== current.value?.id) {
    selectExercise(exercise)
  }
}

function saveDraft() {
  const key = draftKey.value
  if (!key) return
  try {
    if (hasEdits.value) sessionStorage.setItem(key, JSON.stringify({ code: code.value, stdin: stdin.value }))
    else sessionStorage.removeItem(key)
    draftUnavailable.value = false
  } catch {
    draftUnavailable.value = true
  }
}

function restoreDraft() {
  const key = draftKey.value
  if (!key) return
  try {
    const saved = sessionStorage.getItem(key)
    if (!saved) return
    const draft = JSON.parse(saved)
    if (typeof draft?.code === 'string' && typeof draft?.stdin === 'string') {
      code.value = draft.code
      stdin.value = draft.stdin
    }
  } catch {
    draftUnavailable.value = true
  }
}

function updateCode(value: string) {
  code.value = value
  saveDraft()
}

function selectExercise(ex: CodeExercise) {
  const version = ++selectionVersion
  error.value = ''
  current.value = ex
  code.value = ex.starterCode || ''
  stdin.value = ''
  draftUnavailable.value = false
  restoreDraft()
  runResult.value = null
  judgeResult.value = null
  submissions.value = []
  showHint.value = false
  running.value = false
  submitting.value = false
  if (!runtime.value && !runtimeError.value) void loadRuntime()
  void loadSubmissions(ex.id, version)
  try {
    const raw = sessionStorage.getItem('javacourse.lab.snippet')
    if (raw) {
      sessionStorage.removeItem('javacourse.lab.snippet')
      const payload = JSON.parse(raw)
      if (!hasEdits.value && typeof payload?.code === 'string') updateCode(payload.code)
    }
  } catch {
    // Ignore invalid code handoffs.
  }
}

async function loadSubmissions(exerciseId: number, version: number) {
  try {
    const result = await codeApi.submissions(exerciseId)
    if (version === selectionVersion) submissions.value = result
  } catch {
    if (version === selectionVersion) submissions.value = []
  }
}

async function doRun() {
  if (!ready.value || running.value) return
  const version = selectionVersion
  const source = code.value
  const input = stdin.value
  const matchesEditor = () => version === selectionVersion && source === code.value && input === stdin.value
  running.value = true
  error.value = ''
  runResult.value = null
  judgeResult.value = null
  try {
    const result = await codeApi.run(source, input)
    if (matchesEditor()) runResult.value = result
  } catch (e) {
    if (matchesEditor()) error.value = errMsg(e)
  } finally {
    if (version === selectionVersion) running.value = false
  }
}

async function doSubmit() {
  if (!ready.value || submitting.value || !current.value) return
  const version = selectionVersion
  const exerciseId = current.value.id
  const source = code.value
  submitting.value = true
  error.value = ''
  judgeResult.value = null
  try {
    const result = await codeApi.submit(exerciseId, source)
    if (version === selectionVersion) {
      if (source === code.value) judgeResult.value = result
      await loadSubmissions(exerciseId, version)
    }
  } catch (e) {
    if (version === selectionVersion && source === code.value) error.value = errMsg(e)
  } finally {
    if (version === selectionVersion) submitting.value = false
  }
}

/** 编译错误里解析出「行号」，点击可跳到那一行 */
function jumpTo(line: number) {
  editorRef.value?.gotoLine(line)
}

function resetCode() {
  if (current.value) {
    updateCode(current.value.starterCode || '')
    runResult.value = null
    judgeResult.value = null
  }
}

watch(slug, (selectedSlug) => {
  if (selectedSlug && !loading.value) selectBySlug(selectedSlug)
})

watch(account, (next, previous) => {
  if (!current.value) return
  if (previous != null) selectExercise(current.value)
  else if (next != null) {
    if (hasEdits.value) saveDraft()
    else restoreDraft()
  }
})

watch([code, stdin], () => {
  runResult.value = null
  error.value = ''
})
watch(code, () => { judgeResult.value = null })

onMounted(load)
</script>

<template>
  <div class="container ex">
    <div v-if="loading" class="card ex__loading" role="status">加载中…</div>
    <div v-else-if="loadError" class="card ex__loading" role="alert">
      <p>{{ loadError }}</p>
      <button class="btn btn--primary" type="button" @click="load">重试加载</button>
    </div>
    <template v-else-if="!slug">
      <header class="ex__catalog-heading">
        <div>
          <h1 class="title-round">代码练习</h1>
          <p>选一道题，在线编写、运行并提交判题。</p>
        </div>
        <RouterLink :to="{ name: 'qa' }" class="btn btn--ghost">知识题库 →</RouterLink>
      </header>
      <PracticeTopics v-if="topics.length" :topics="topics" :selected="topicId"
        @select="$event ? setFilter('topic', $event) : clearFilters(true)" />
      <div class="ex__filters" aria-label="筛选代码练习">
        <label class="ex__field ex__field--search">关键词<input v-model="keyword" type="search" placeholder="搜题名、课时或题意" /></label>
        <label class="ex__field">难度
          <select v-model="difficulty"><option value="">全部难度</option><option v-for="level in practiceLevels" :key="level.id" :value="level.id">{{ level.label }}</option></select>
        </label>
        <label class="ex__field">来源
          <select :value="resourceOnly ? 'all' : ''" @change="setFilter('resource', ($event.target as HTMLSelectElement).value)">
            <option value="">全部来源</option><option value="all">资料库练习</option>
          </select>
        </label>
        <button v-if="filtersActive" class="btn btn--sm btn--ghost" type="button" @click="clearFilters()">清除筛选</button>
      </div>
      <section v-if="topicId || filtersActive" aria-labelledby="ex-results">
        <div class="ex__results-head">
          <h2 id="ex-results" class="title-round">{{ topic?.title || '筛选结果' }}</h2>
          <span role="status">{{ shownExercises.length }} 道题</span>
        </div>
        <p v-if="!shownExercises.length" class="card ex__loading">没有匹配的练习，试试更换分区或筛选条件。</p>
        <ul v-else class="ex__catalog-list">
          <li v-for="exercise in shownExercises" :key="exercise.id">
            <RouterLink class="ex__catalog-item card" :to="{ name: 'exercise', params: { slug: exercise.slug }, query: route.query }">
              <div>
                <strong>{{ exercise.title }}</strong>
                <span class="ex__catalog-lesson">{{ exercise.lessonTitle || '通用练习' }}</span>
              </div>
              <span class="badge badge--lilac">{{ practiceLevelLabel(exercise.difficulty) }}</span>
              <span aria-hidden="true">→</span>
            </RouterLink>
          </li>
        </ul>
      </section>
      <p v-else-if="!exercises.length" class="card ex__loading">暂时没有代码练习。</p>
    </template>
    <template v-else>
      <RouterLink class="ex__back" :to="{ name: 'exercises', query: route.query }">← 返回练习目录</RouterLink>
      <div v-if="error && !current" class="card ex__loading" role="alert">{{ error }}</div>
      <section v-else-if="current" class="ex__main">
        <div v-if="!ready" class="ex__alert ex__alert--warn">
          <p role="status">{{ checkingRuntime ? '正在检查 Java 运行环境，可以先编辑代码。' : runtimeError || runtime?.note || 'Java 运行环境暂未就绪。' }}</p>
          <button v-if="!checkingRuntime" type="button" class="btn btn--sm btn--ghost" @click="loadRuntime">重试检测</button>
        </div>
        <!-- 题面 -->
        <div class="card ex__head">
          <div class="ex__head-top">
            <span class="badge badge--coral">{{ practiceLevelLabel(current.difficulty) }}</span>
            <RouterLink v-if="current.lessonSlug" class="badge badge--mint" :to="{ name: 'lesson', params: { slug: current.lessonSlug } }">{{ current.lessonTitle }}</RouterLink>
            <span v-if="resourceNote" class="badge badge--lilac">资料库</span>
            <button class="btn btn--sm btn--ghost" @click="resetCode">重置代码</button>
          </div>
          <h1 class="title-round ex__title">{{ current.title }}</h1>
          <pre class="ex__desc">{{ current.description }}</pre>
          <div v-if="resourceNote" class="ex__resource-links">
            <RouterLink class="btn btn--sm btn--ghost" :to="{ name: 'resources', params: { note: resourceNote.id } }">来源讲解</RouterLink>
            <RouterLink class="btn btn--sm btn--ghost" :to="{ name: 'qa', query: { resource: resourceNote.id } }">专题题库</RouterLink>
          </div>
          <p v-if="caseNames.length" class="ex__cases-hint">
            本题共 {{ caseNames.length }} 个测试用例：{{ caseNames.join('、') }}
          </p>
          <button v-if="current.hint" class="ex__hint-toggle" @click="showHint = !showHint">
            {{ showHint ? '收起提示' : '💡 需要提示？' }}
          </button>
          <pre v-if="showHint && current.hint" class="ex__hint">{{ current.hint }}</pre>
        </div>

        <!-- 编辑器 + 结果 -->
        <div class="card ex__work">
          <div class="ex__toolbar">
            <button class="btn btn--primary" :disabled="!ready || running" @click="doRun">
              {{ running ? '运行中…' : '▶ 运行' }}
            </button>
            <button class="btn btn--sun" :disabled="!ready || submitting" @click="doSubmit">
              {{ submitting ? '判题中…' : '✓ 提交判题' }}
            </button>
            <span class="ex__kbd">快捷键：Ctrl + Enter 运行</span>
            <span v-if="error" class="ex__err">{{ error }}</span>
          </div>

          <div class="ex__editor">
            <CodeEditor
              ref="editorRef"
              :model-value="code"
              :min-rows="16"
              :max-rows="30"
              @update:model-value="updateCode"
              @run="doRun"
            />
          </div>

          <!-- 标准输入 -->
          <div class="ex__stdin">
            <label class="ex__stdin-label">
              标准输入（stdin）
              <span class="ex__stdin-hint">题目要求读入数据时填在这里，会作为程序输入</span>
            </label>
            <textarea
              v-model="draftInput"
              class="ex__stdin-box"
              rows="2"
              placeholder="例如：&#10;5&#10;1 2 3 4 5"
            />
            <p v-if="draftUnavailable" class="ex__draft" role="status">当前浏览器无法保存或读取草稿。</p>
            <p v-else-if="hasEdits && draftKey" class="ex__draft">草稿已保存在当前标签页。</p>
            <p v-else-if="hasEdits" class="ex__draft" role="status">登录资料读取后可保存草稿。</p>
          </div>

          <!-- 运行结果 -->
          <p v-if="running" role="status">正在等待服务器返回运行结果…</p>
          <div v-if="runResult" class="ex__result">
            <div class="ex__result-head">
              <span class="ex__status" :class="runResult.success ? 'is-pass' : 'is-err'">
                {{ runResult.success ? '✓ 编译并运行成功' : '✗ ' + runResult.message }}
              </span>
            </div>
            <CodeRunTiming :result="runResult" />
            <div v-if="runResult.output" class="ex__block">
              <div class="ex__block-label">编译器输出</div>
              <pre class="ex__pre ex__pre--err">{{ runResult.output }}</pre>
            </div>
            <div v-if="runResult.stdout" class="ex__block">
              <div class="ex__block-label">标准输出</div>
              <pre class="ex__pre ex__pre--out">{{ runResult.stdout }}</pre>
            </div>
            <div v-if="runResult.stderr" class="ex__block">
              <div class="ex__block-label">标准错误 / 异常栈</div>
              <pre class="ex__pre ex__pre--err">{{ runResult.stderr }}</pre>
            </div>
          </div>

          <!-- 判题结果 -->
          <div v-if="judgeResult" class="ex__result">
            <div class="ex__result-head">
              <span class="ex__status" :class="statusMeta?.cls">{{ statusMeta?.icon }} {{ statusMeta?.label }}</span>
              <span class="ex__score">
                {{ judgeResult.passedCount }} / {{ judgeResult.totalCount }} 用例通过
              </span>
              <span class="ex__duration">{{ judgeResult.durationMs }} ms</span>
            </div>
            <p class="ex__judge-msg">{{ judgeResult.message }}</p>

            <div v-if="judgeResult.cases?.length" class="ex__cases">
              <div
                v-for="(c, i) in judgeResult.cases"
                :key="i"
                class="ex__case"
                :class="c.passed ? 'is-pass' : 'is-fail'"
              >
                <div class="ex__case-head">
                  <span>{{ c.passed ? '✓' : '✗' }} {{ c.name }}</span>
                  <span v-if="!c.passed && c.note" class="ex__case-note">{{ c.note }}</span>
                </div>
                <div v-if="!c.passed" class="ex__case-diff">
                  <div class="ex__case-side">
                    <span class="ex__case-tag">期望输出</span>
                    <pre class="ex__pre ex__pre--out">{{ c.expected || '（空）' }}</pre>
                  </div>
                  <div class="ex__case-side">
                    <span class="ex__case-tag">你的输出</span>
                    <pre class="ex__pre ex__pre--out">{{ c.actual || '（空）' }}</pre>
                  </div>
                </div>
              </div>
            </div>

            <div v-if="judgeResult.errorOutput" class="ex__block">
              <div class="ex__block-label">编译错误 / 异常信息</div>
              <pre class="ex__pre ex__pre--err">{{ judgeResult.errorOutput }}</pre>
            </div>
          </div>

          <!-- 历史提交 -->
          <div v-if="submissions.length" class="ex__history">
            <div class="ex__block-label">我的提交记录</div>
            <table class="ex__table">
              <thead>
                <tr><th>时间</th><th>结果</th><th>通过</th><th>耗时</th></tr>
              </thead>
              <tbody>
                <tr v-for="s in submissions" :key="s.id">
                  <td>{{ s.createdAt }}</td>
                  <td>
                    <span class="ex__status-sm" :class="s.status === 'PASSED' ? 'is-pass' : 'is-fail'">
                      {{ s.status }}
                    </span>
                  </td>
                  <td>{{ s.passedCount }}/{{ s.totalCount }}</td>
                  <td>{{ s.durationMs }} ms</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>
    </template>
  </div>
</template>

<style scoped>
.ex__resource-links { display: flex; flex-wrap: wrap; gap: 8px; margin-block: 10px; }
.ex {
  padding-block: var(--space-lg) var(--space-xl);
}

/* ---------- 环境横幅 ---------- */
.ex__alert {
  padding: 14px 18px;
  border: var(--bw-base) solid var(--c-line);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
  margin-bottom: var(--space-md);
  font-size: 14px;
  line-height: 1.7;
}
.ex__alert p { margin: 4px 0 0; color: var(--c-ink-soft); }
.ex__alert--warn { background: var(--c-cream-deep); }
.ex__alert .btn { margin-top: 8px; }
.ex__catalog-heading, .ex__results-head { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; }
.ex__catalog-heading h1 { margin: 0 0 6px; font-size: 34px; }
.ex__catalog-heading p { margin: 0; color: var(--c-ink-soft); }
.ex__filters { display: flex; flex-wrap: wrap; align-items: end; gap: 10px; margin-bottom: 24px; padding: 14px; background: var(--c-cream); border: 1px solid #d0c5e6; border-radius: var(--radius-md); }
.ex__field { display: grid; gap: 5px; min-width: 0; font-size: 13px; font-weight: 700; }
.ex__field--search { flex: 1 1 180px; }
.ex__field :is(input,select) { width: 100%; min-width: 0; max-width: 100%; padding: 8px 9px; border: 1px solid #8e85a6; border-radius: 8px; background: var(--c-paper); color: var(--c-ink); font: inherit; font-weight: 400; }
.ex__results-head h2 { margin: 0; }
.ex__catalog-list { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; padding: 0; list-style: none; }
.ex__catalog-item { display: grid; grid-template-columns: minmax(0, 1fr) auto auto; align-items: center; gap: 10px; height: 100%; padding: 14px; color: var(--c-ink); text-decoration: none; }
.ex__catalog-item:hover { background: #f4efff; }
.ex__catalog-lesson { display: block; margin-top: 3px; color: var(--c-ink-soft); font-size: .81rem; }
.ex__back { display: inline-block; margin-bottom: 15px; color: var(--c-ink-soft); }
.ex__main { max-width: 1020px; margin-inline: auto; }

@media (max-width: 700px) {
  .ex__catalog-list { grid-template-columns: minmax(0, 1fr); }
  .ex__field { flex: 1 1 105px; }
  .ex__field--search { flex-basis: 100%; }
}

/* ---------- 题面 ---------- */
.ex__head { padding: var(--space-md); margin-bottom: var(--space-md); }
.ex__head-top { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-bottom: 8px; }
.ex__head-top .btn { margin-left: auto; }
.ex__title { font-size: 24px; margin: 0 0 10px; }
.ex__desc {
  font-family: var(--font-body);
  font-size: 14px;
  line-height: 1.8;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  color: var(--c-ink-soft);
  margin: 0;
}
.ex__cases-hint { font-size: 12px; color: var(--c-ink-faint); margin: 10px 0 0; }
.ex__hint-toggle {
  margin-top: 10px;
  background: none;
  border: none;
  color: var(--c-coral-deep);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  padding: 0;
}
.ex__hint {
  margin: 8px 0 0;
  padding: 10px 12px;
  background: var(--c-sun);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-md);
  font-size: 13px;
  line-height: 1.7;
  white-space: pre-wrap;
  color: var(--c-ink);
}

/* ---------- 工作区 ---------- */
.ex__work { padding: var(--space-md); }
.ex__toolbar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 12px;
}
.ex__kbd { font-size: 12px; color: var(--c-ink-faint); }
.ex__err { font-size: 13px; color: var(--c-coral-deep); font-weight: 700; }

.ex__editor { margin-bottom: 12px; }

.ex__stdin { margin-bottom: 14px; }
.ex__stdin-label {
  display: block;
  font-size: 13px;
  font-weight: 700;
  color: var(--c-ink);
  margin-bottom: 6px;
}
.ex__stdin-hint { font-weight: 400; color: var(--c-ink-faint); margin-left: 8px; font-size: 12px; }
.ex__stdin-box {
  width: 100%;
  padding: 10px 12px;
  font-family: 'Cascadia Code', Consolas, monospace;
  font-size: 13px;
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-md);
  background: var(--c-cream);
  color: var(--c-ink);
  outline: none;
  resize: vertical;
}
.ex__stdin-box:focus { border-color: var(--c-mint-deep); }
.ex__draft { margin: 6px 0 0; font-size: .875rem; color: var(--c-ink-soft); }

/* ---------- 结果 ---------- */
.ex__result {
  margin-top: 16px;
  border-top: var(--bw-thin) dashed var(--c-line);
  padding-top: 14px;
}
.ex__result-head { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
.ex__status {
  padding: 3px 12px;
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-full);
  font-size: 13px;
  font-weight: 800;
  font-family: var(--font-round);
}
.ex__status.is-pass { background: #51cf66; color: #14361a; }
.ex__status.is-fail { background: var(--c-sun); color: var(--c-ink); }
.ex__status.is-err { background: var(--c-coral); color: #fff; }
.ex__status-sm {
  padding: 1px 8px;
  border: 1px solid var(--c-line);
  border-radius: var(--radius-full);
  font-size: 11px;
  font-weight: 800;
}
.ex__status-sm.is-pass { background: #51cf66; }
.ex__status-sm.is-fail { background: var(--c-peach); }
.ex__score { font-size: 13px; font-weight: 700; color: var(--c-ink-soft); }
.ex__duration { margin-left: auto; font-size: 12px; color: var(--c-ink-faint); }
.ex__judge-msg { font-size: 14px; color: var(--c-ink-soft); margin: 8px 0 0; }

.ex__block { margin-top: 12px; }
.ex__block-label {
  font-size: 12px;
  font-weight: 800;
  color: var(--c-ink-soft);
  margin-bottom: 5px;
  letter-spacing: .04em;
}
.ex__pre {
  margin: 0;
  padding: 12px 14px;
  border-radius: var(--radius-md);
  border: var(--bw-thin) solid var(--c-line);
  font-family: 'Cascadia Code', Consolas, monospace;
  font-size: 12.5px;
  line-height: 1.65;
  white-space: pre-wrap;
  word-break: break-word;
  max-height: 340px;
  overflow: auto;
}
.ex__pre--out { background: #1e2544; color: #c8f7d0; }
.ex__pre--err { background: #3a1f2b; color: #ffd3d3; }

/* ---------- 用例明细 ---------- */
.ex__cases { margin-top: 12px; display: flex; flex-direction: column; gap: 8px; }
.ex__case {
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-md);
  padding: 9px 12px;
  font-size: 13px;
}
.ex__case.is-pass { background: #e6fbe9; }
.ex__case.is-fail { background: var(--c-cream-deep); }
.ex__case-head { display: flex; align-items: center; gap: 10px; font-weight: 700; }
.ex__case-note { font-weight: 400; color: var(--c-coral-deep); font-size: 12px; }
.ex__case-diff { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 8px; }
@media (max-width: 700px) { .ex__case-diff { grid-template-columns: 1fr; } }
.ex__case-tag {
  display: block;
  font-size: 11px;
  font-weight: 800;
  color: var(--c-ink-faint);
  margin-bottom: 4px;
}

/* ---------- 历史 ---------- */
.ex__history { margin-top: 18px; }
.ex__table { width: 100%; border-collapse: collapse; font-size: 13px; }
.ex__table th,
.ex__table td {
  text-align: left;
  padding: 7px 10px;
  border-bottom: 1px solid var(--c-line);
  color: var(--c-ink-soft);
}
.ex__table th { font-size: 12px; color: var(--c-ink-faint); font-weight: 800; }

.ex__loading { padding: var(--space-lg); text-align: center; color: var(--c-ink-faint); }
</style>
