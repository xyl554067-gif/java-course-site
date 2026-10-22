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
import { codeApi, type CodeExercise, type CodeRuntime, type JudgeResult, type CodeRunResult, type CodeSubmission } from '@/api'
import { errMsg } from '@/api/http'

const route = useRoute()
const router = useRouter()

const exercises = ref<CodeExercise[]>([])
const runtime = ref<CodeRuntime | null>(null)
const current = ref<CodeExercise | null>(null)
const code = ref('')
const stdin = ref('')
const runResult = ref<CodeRunResult | null>(null)
const judgeResult = ref<JudgeResult | null>(null)
const submissions = ref<CodeSubmission[]>([])
const loading = ref(false)
const running = ref(false)
const submitting = ref(false)
const error = ref('')
const showHint = ref(false)
const editorRef = ref<InstanceType<typeof CodeEditor> | null>(null)

const ready = computed(() => runtime.value?.ready === true)

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
  error.value = ''
  try {
    const [rt, list] = await Promise.all([
      codeApi.runtime().catch(() => null),
      codeApi.exercises(),
    ])
    runtime.value = rt
    exercises.value = list
    if (list.length) {
      const slug = (route.params.slug as string) || list[0].slug
      const found = list.find((e) => e.slug === slug) || list[0]
      selectExercise(found)
    } else {
      error.value = '暂无习题数据'
    }
  } catch (e) {
    error.value = errMsg(e)
  } finally {
    loading.value = false
  }
}

function selectExercise(ex: CodeExercise) {
  current.value = ex
  code.value = ex.starterCode || ''
  stdin.value = ''
  runResult.value = null
  judgeResult.value = null
  showHint.value = false
  if (route.params.slug !== ex.slug) {
    void router.replace({ name: 'exercise', params: { slug: ex.slug } })
  }
  void loadSubmissions(ex.id)
}

async function loadSubmissions(exerciseId: number) {
  try {
    submissions.value = await codeApi.submissions(exerciseId)
  } catch {
    submissions.value = []
  }
}

async function doRun() {
  if (!ready.value || running.value) return
  running.value = true
  judgeResult.value = null
  try {
    runResult.value = await codeApi.run(code.value, stdin.value)
  } catch (e) {
    error.value = errMsg(e)
  } finally {
    running.value = false
  }
}

async function doSubmit() {
  if (!ready.value || submitting.value || !current.value) return
  submitting.value = true
  try {
    judgeResult.value = await codeApi.submit(current.value.id, code.value)
    await loadSubmissions(current.value.id)
  } catch (e) {
    error.value = errMsg(e)
  } finally {
    submitting.value = false
  }
}

/** 编译错误里解析出「行号」，点击可跳到那一行 */
function jumpTo(line: number) {
  editorRef.value?.gotoLine(line)
}

function resetCode() {
  if (current.value) {
    code.value = current.value.starterCode || ''
    runResult.value = null
    judgeResult.value = null
  }
}

watch(() => route.params.slug, async (slug) => {
  if (!slug || !exercises.value.length) return
  const found = exercises.value.find((e) => e.slug === slug)
  if (found && found.id !== current.value?.id) {
    selectExercise(found)
  }
})

onMounted(async () => {
  await load()
  // 从课时页「✎ 在编辑器中打开」带过来的示例代码
  try {
    const raw = sessionStorage.getItem('javacourse.lab.snippet')
    if (raw) {
      sessionStorage.removeItem('javacourse.lab.snippet')
      const payload = JSON.parse(raw)
      if (payload?.code) {
        code.value = payload.code
        runResult.value = null
        judgeResult.value = null
      }
    }
  } catch {
    /* 忽略 */
  }
})
</script>

<template>
  <div class="container ex">
    <!-- 环境自检横幅 -->
    <div v-if="runtime && !ready" class="ex__alert ex__alert--warn">
      <strong>⚠ 代码执行环境未就绪</strong>
      <p>{{ runtime.note }}</p>
      <p class="ex__alert-hint">
        配置方式：安装 JDK 17+ 后设置环境变量 <code>CODE_JAVA_HOME</code> 指向 JDK 根目录，
        或在 <code>application.yml</code> 里设置 <code>app.code.java-home</code>，然后重启后端。
      </p>
    </div>
    <div v-else-if="runtime" class="ex__alert ex__alert--ok">
      <strong>✓ 代码执行环境就绪</strong>
      <p>
        {{ runtime.javacVersion }} ｜ 单次运行上限 {{ runtime.timeoutMs }}ms ｜
        堆上限 {{ runtime.memoryLimitMb }}MB ｜ 输出上限 {{ runtime.maxOutputChars }} 字符
      </p>
    </div>

    <div class="ex__layout">
      <!-- 左侧：习题列表 -->
      <aside class="card ex__side">
        <div class="section-head">
          <span class="dot" /><h2>课后习题</h2><span class="line" />
        </div>
        <p class="ex__side-tip">共 {{ exercises.length }} 道，写完点「提交」自动判题</p>
        <button
          v-for="e in exercises"
          :key="e.id"
          class="ex__item"
          :class="{ 'is-active': current?.id === e.id }"
          @click="selectExercise(e)"
        >
          <strong>{{ e.title }}</strong>
          <span class="ex__item-meta">
            <span class="badge badge--lilac">{{ e.difficulty }}</span>
            <span class="ex__item-lesson">{{ e.lessonTitle }}</span>
          </span>
        </button>
      </aside>

      <!-- 右侧：题目 + 编辑器 + 结果 -->
      <section class="ex__main">
        <div v-if="loading" class="card ex__loading">加载中…</div>

        <div v-else-if="error && !current" class="card ex__loading">{{ error }}</div>

        <template v-else-if="current">
          <!-- 题面 -->
          <div class="card ex__head">
            <div class="ex__head-top">
              <span class="badge badge--coral">{{ current.difficulty }}</span>
              <span v-if="current.lessonTitle" class="badge badge--mint">{{ current.lessonTitle }}</span>
              <button class="btn btn--sm btn--ghost" @click="resetCode">重置代码</button>
            </div>
            <h1 class="title-round ex__title">{{ current.title }}</h1>
            <pre class="ex__desc">{{ current.description }}</pre>
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
                v-model="code"
                :readonly="!ready"
                :min-rows="16"
                :max-rows="30"
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
                v-model="stdin"
                class="ex__stdin-box"
                rows="2"
                placeholder="例如：&#10;5&#10;1 2 3 4 5"
              />
            </div>

            <!-- 运行结果 -->
            <div v-if="runResult" class="ex__result">
              <div class="ex__result-head">
                <span class="ex__status" :class="runResult.success ? 'is-pass' : 'is-err'">
                  {{ runResult.success ? '✓ 编译并运行成功' : '✗ ' + runResult.message }}
                </span>
                <span class="ex__duration">{{ runResult.durationMs }} ms</span>
              </div>
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
        </template>
      </section>
    </div>
  </div>
</template>

<style scoped>
.ex {
  padding: var(--space-lg) 0;
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
.ex__alert--ok { background: #e6fbe9; }
.ex__alert--warn { background: var(--c-cream-deep); }
.ex__alert-hint { font-size: 13px; }
.ex__alert code {
  background: var(--c-paper);
  border: 1px solid var(--c-line);
  border-radius: 4px;
  padding: 1px 6px;
  font-size: 12px;
}

/* ---------- 布局 ---------- */
.ex__layout {
  display: grid;
  grid-template-columns: 270px 1fr;
  gap: var(--space-md);
  align-items: start;
}
@media (max-width: 900px) {
  .ex__layout { grid-template-columns: 1fr; }
}

/* ---------- 侧栏 ---------- */
.ex__side { padding: var(--space-md); position: sticky; top: 90px; }
.ex__side-tip { font-size: 12px; color: var(--c-ink-faint); margin: 6px 0 12px; }
.ex__item {
  display: block;
  width: 100%;
  text-align: left;
  padding: 10px 12px;
  margin-bottom: 8px;
  background: var(--c-cream);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-size: 14px;
  color: var(--c-ink);
  transition: transform .12s ease, background .12s ease;
}
.ex__item:hover { background: var(--c-sun); transform: translateX(2px); }
.ex__item.is-active {
  background: var(--c-mint);
  color: #fff;
  box-shadow: 3px 3px 0 var(--c-line);
}
.ex__item-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 5px;
}
.ex__item-lesson { font-size: 11px; opacity: .8; }

/* ---------- 题面 ---------- */
.ex__head { padding: var(--space-md); margin-bottom: var(--space-md); }
.ex__head-top { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
.ex__head-top .btn { margin-left: auto; }
.ex__title { font-size: 24px; margin: 0 0 10px; }
.ex__desc {
  font-family: var(--font-body);
  font-size: 14px;
  line-height: 1.8;
  white-space: pre-wrap;
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
