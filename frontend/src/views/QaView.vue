<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { courseApi, type QaItem, type QaLessonOption } from '@/api'
import { errMsg } from '@/api/http'

const items = ref<QaItem[]>([])
const lessons = ref<QaLessonOption[]>([])
const loading = ref(true)
const filter = ref('ALL')
const revealed = ref<Record<number, boolean>>({})
const showEditor = ref(false)
const editingId = ref<number | null>(null)
const saving = ref(false)
const importing = ref(false)
const error = ref('')
const importMessage = ref('')
const importPreview = ref<Record<string, unknown>[]>([])
const importFileName = ref('')
const importInput = ref<HTMLInputElement | null>(null)

const FILTERS = [
  { key: 'ALL', label: '全部' },
  { key: 'CHOICE', label: '选择题' },
  { key: 'JUDGE', label: '判断题' },
  { key: 'SHORT_ANSWER', label: '简答题' },
]
const DIFF_BADGE: Record<string, string> = { EASY: 'badge--mint', MEDIUM: 'badge--sun', HARD: 'badge--coral' }
const DIFF_LABEL: Record<string, string> = { EASY: '简单', MEDIUM: '中等', HARD: '较难' }

const form = ref({
  lessonId: '',
  question: '',
  qaType: 'CHOICE',
  difficulty: 'MEDIUM',
  answer: '',
  answerKey: 'A',
  optionsLines: '',
})

const list = computed(() => filter.value === 'ALL' ? items.value : items.value.filter((item) => normalizeType(item.qaType) === filter.value))
const choiceOptions = computed(() => {
  if (!form.value.optionsLines.trim()) return []
  return form.value.optionsLines.split(/\r?\n/).map((line) => line.trim()).filter(Boolean)
})
const previewErrors = computed(() => importPreview.value.flatMap((item, index) => {
  const errors: string[] = []
  const question = String(item.question ?? '').trim()
  const rawType = String(item.qaType ?? item.type ?? '').trim().toUpperCase()
  const type = rawType === 'SINGLE_CHOICE' || rawType === 'MULTIPLE_CHOICE' ? 'CHOICE' : rawType === 'SHORT' || rawType === 'TEXT' ? 'SHORT_ANSWER' : rawType
  const answer = String(item.answer ?? item.answerText ?? '').trim()
  const answerKey = String(item.answerKey ?? item.answer_key ?? '').trim()
  if (!question) errors.push(`第 ${index + 1} 道题缺少题目内容`)
  if (!['CHOICE', 'JUDGE', 'SHORT_ANSWER'].includes(type)) errors.push(`第 ${index + 1} 道题题型无效或是代码题`)
  if (!answer && !answerKey) errors.push(`第 ${index + 1} 道题缺少答案`)
  if (type === 'CHOICE') {
    let options: unknown = item.options
    try { if (typeof options === 'string') options = JSON.parse(options) } catch { options = null }
    if (!Array.isArray(options) || options.length < 2) errors.push(`第 ${index + 1} 道选择题至少需要两个选项`)
    else if (!/^[A-Z]$/i.test(answerKey) || answerKey.toUpperCase().charCodeAt(0) - 65 >= options.length) errors.push(`第 ${index + 1} 道选择题答案标号超出选项范围`)
  }
  if (type === 'JUDGE' && !['TRUE', 'FALSE', 'T', 'F', 'YES', 'NO', '对', '错', '正确', '错误'].includes(answerKey.toUpperCase())) errors.push(`第 ${index + 1} 道判断题答案请填写 TRUE/FALSE 或 对/错`)
  const lessonSlug = String(item.lessonSlug ?? item.lesson_slug ?? '').trim()
  if (lessonSlug && !lessons.value.some((lesson) => lesson.slug === lessonSlug)) errors.push(`第 ${index + 1} 道题关联课时不存在：${lessonSlug}`)
  return errors
}))

function normalizeType(type: string) {
  if (type === 'SINGLE_CHOICE' || type === 'MULTIPLE_CHOICE') return 'CHOICE'
  if (type === 'SHORT' || type === 'TEXT') return 'SHORT_ANSWER'
  return type
}

function typeLabel(type: string) {
  switch (normalizeType(type)) {
    case 'CHOICE': return '选择题'
    case 'JUDGE': return '判断题'
    case 'SHORT_ANSWER': return '简答题'
    case 'CODE': return '旧版代码问答'
    default: return '旧版题目'
  }
}

function parseOptions(raw: string | null) {
  if (!raw) return [] as string[]
  try {
    const parsed = JSON.parse(raw)
    return Array.isArray(parsed) ? parsed.map(String) : []
  } catch { return [] as string[] }
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [questionList, lessonList] = await Promise.all([courseApi.qa(), courseApi.qaLessons()])
    items.value = questionList
    lessons.value = lessonList
  } catch (e) {
    error.value = errMsg(e)
  } finally {
    loading.value = false
  }
}

function resetForm() {
  form.value = { lessonId: '', question: '', qaType: 'CHOICE', difficulty: 'MEDIUM', answer: '', answerKey: 'A', optionsLines: '' }
  editingId.value = null
}

function openNew() {
  resetForm()
  showEditor.value = true
  importMessage.value = ''
}

function openEdit(item: QaItem) {
  const options = parseOptions(item.options)
  editingId.value = item.id
  form.value = {
    lessonId: item.lessonId == null ? '' : String(item.lessonId),
    question: item.question,
    qaType: normalizeType(item.qaType) === 'CODE' ? 'SHORT_ANSWER' : normalizeType(item.qaType),
    difficulty: item.difficulty,
    answer: item.answer || '',
    answerKey: item.answerKey || (normalizeType(item.qaType) === 'JUDGE' ? 'TRUE' : 'A'),
    optionsLines: options.join('\n'),
  }
  showEditor.value = true
  importMessage.value = ''
}

function onTypeChange() {
  form.value.answerKey = form.value.qaType === 'CHOICE' ? 'A' : form.value.qaType === 'JUDGE' ? 'TRUE' : ''
}

async function saveQuestion() {
  error.value = ''
  const question = form.value.question.trim()
  const answer = form.value.answer.trim()
  if (!question) { error.value = '请填写题目内容'; return }
  if (!answer && !form.value.answerKey.trim()) { error.value = '请填写答案或解析'; return }
  if (form.value.qaType === 'CHOICE' && choiceOptions.value.length < 2) { error.value = '选择题至少填写两个选项'; return }

  const payload = {
    lessonId: form.value.lessonId ? Number(form.value.lessonId) : null,
    question,
    answer,
    answerKey: form.value.qaType === 'SHORT_ANSWER' ? '' : form.value.answerKey.trim(),
    qaType: form.value.qaType,
    difficulty: form.value.difficulty,
    options: form.value.qaType === 'CHOICE' ? JSON.stringify(choiceOptions.value) : null,
  }
  saving.value = true
  try {
    if (editingId.value == null) await courseApi.createQa(payload)
    else await courseApi.updateQa(editingId.value, payload)
    showEditor.value = false
    resetForm()
    await load()
  } catch (e) {
    error.value = errMsg(e)
  } finally {
    saving.value = false
  }
}

async function deleteQuestion(item: QaItem) {
  if (!window.confirm('删除这道个人题目？')) return
  error.value = ''
  try {
    await courseApi.deleteQa(item.id)
    await load()
  } catch (e) { error.value = errMsg(e) }
}

function parseCsv(text: string): Record<string, string>[] {
  const rows: string[][] = []
  let row: string[] = [], value = '', quoted = false
  const source = text.replace(/^\uFEFF/, '')
  for (let i = 0; i < source.length; i++) {
    const char = source[i]
    if (quoted) {
      if (char === '"' && source[i + 1] === '"') { value += '"'; i++ }
      else if (char === '"') quoted = false
      else value += char
    } else if (char === '"') quoted = true
    else if (char === ',') { row.push(value); value = '' }
    else if (char === '\n' || char === '\r') {
      if (char === '\r' && source[i + 1] === '\n') i++
      row.push(value); value = ''
      if (row.some((cell) => cell.trim())) rows.push(row)
      row = []
    } else value += char
  }
  if (quoted) throw new Error('CSV 文件中有未闭合的引号')
  row.push(value)
  if (row.some((cell) => cell.trim())) rows.push(row)
  if (rows.length < 2) throw new Error('CSV 文件需要包含表头和至少一道题目')

  const headers = rows[0].map((header) => header.trim())
  const aliases: Record<string, string> = { type: 'qaType', answerText: 'answer', lesson_slug: 'lessonSlug', lesson: 'lessonSlug' }
  return rows.slice(1).map((cells) => Object.fromEntries(headers.map((header, i) => [aliases[header] || header, cells[i] || ''])))
}

async function importFile(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  importing.value = true
  error.value = ''
  importMessage.value = ''
  importPreview.value = []
  try {
    const text = await file.text()
    let parsed: Record<string, unknown>[]
    if (file.name.toLowerCase().endsWith('.json')) {
      const json = JSON.parse(text)
      const values = Array.isArray(json) ? json : json && Array.isArray(json.items) ? json.items : null
      if (!Array.isArray(values)) throw new Error('JSON 文件应为题目数组或包含 items 数组')
      parsed = values
    } else if (file.name.toLowerCase().endsWith('.csv')) {
      parsed = parseCsv(text)
    } else throw new Error('请使用 .csv 或 .json 文件')

    if (parsed.length > 500) throw new Error('一次最多导入 500 道题')
    if (!parsed.length) throw new Error('导入文件里没有题目')
    importFileName.value = file.name
    importPreview.value = parsed
  } catch (e) {
    error.value = errMsg(e)
  } finally { importing.value = false }
}

async function confirmImport() {
  if (!importPreview.value.length || previewErrors.value.length) return
  importing.value = true
  error.value = ''
  try {
    const result = await courseApi.importQa(importPreview.value)
    importMessage.value = `导入完成：新增 ${result.imported} 道，重复跳过 ${result.skipped} 道。`
    importPreview.value = []
    importFileName.value = ''
    await load()
  } catch (e) { error.value = errMsg(e) }
  finally { importing.value = false }
}

function downloadTemplate() {
  const content = '\uFEFFquestion,qaType,difficulty,answer,answerKey,options,lessonSlug\r\n"Java 程序从哪个方法开始执行？",CHOICE,EASY,"从 main 方法开始执行。",A,"[""A. main()"",""B. start()""]",hello-world\r\n'
  const url = URL.createObjectURL(new Blob([content], { type: 'text/csv;charset=utf-8' }))
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = '题库导入模板.csv'
  anchor.click()
  URL.revokeObjectURL(url)
}

function judgeKey(key: string | null) { return key === 'TRUE' ? '正确' : key === 'FALSE' ? '错误' : key }

onMounted(load)
</script>

<template>
  <div class="container qa">
    <header class="qa__head">
      <div>
        <h1 class="title-round qa__title">知识测验</h1>
        <p class="qa__sub">选择、判断与简答题帮助你检查理解；代码挑战请到独立的代码练习区完成。</p>
      </div>
      <div class="qa__actions">
        <RouterLink class="btn btn--ghost" to="/exercises">代码挑战 →</RouterLink>
        <button class="btn btn--ghost" :disabled="importing" @click="importInput?.click()">{{ importing ? '导入中…' : '导入 CSV / JSON' }}</button>
        <button class="btn btn--primary" @click="openNew">＋ 新建题目</button>
        <input ref="importInput" type="file" accept=".csv,.json,text/csv,application/json" hidden @change="importFile" />
      </div>
    </header>

    <div class="qa__tools">
      <div class="qa__filters">
        <button v-for="f in FILTERS" :key="f.key" class="btn btn--sm" :class="filter === f.key ? 'btn--primary' : 'btn--ghost'" @click="filter = f.key">{{ f.label }}</button>
      </div>
      <button class="template-link" @click="downloadTemplate">下载导入模板</button>
    </div>

    <p v-if="importMessage" class="qa__notice">{{ importMessage }}</p>
    <p v-if="error" class="qa__error" role="alert">{{ error }}</p>

    <section v-if="importPreview.length" class="card qa-import-preview">
      <div class="qa-import-preview__head"><div><h2>确认导入</h2><p>{{ importFileName }} · 共 {{ importPreview.length }} 道题，以下为前 {{ Math.min(importPreview.length, 8) }} 道预览</p></div><button class="icon-close" aria-label="取消导入" @click="importPreview = []; importFileName = ''">×</button></div>
      <p v-if="previewErrors.length" class="qa__error">{{ previewErrors.slice(0, 4).join('；') }}<span v-if="previewErrors.length > 4">，另有 {{ previewErrors.length - 4 }} 个问题</span></p>
      <div class="qa-import-preview__rows"><article v-for="(item, index) in importPreview.slice(0, 8)" :key="index"><b>{{ index + 1 }}. {{ item.question || '（缺少题目内容）' }}</b><span>{{ item.qaType || item.type || '未填写题型' }} · {{ item.difficulty || 'MEDIUM' }} · {{ item.lessonSlug || '通用题' }}</span></article></div>
      <div class="qa-import-preview__actions"><button class="btn btn--ghost" @click="importPreview = []; importFileName = ''">取消</button><button class="btn btn--primary" :disabled="importing || previewErrors.length > 0" @click="confirmImport">{{ importing ? '导入中…' : `确认导入 ${importPreview.length} 道题` }}</button></div>
    </section>

    <section v-if="showEditor" class="card qa-editor">
      <div class="qa-editor__head"><h2>{{ editingId == null ? '新建个人题目' : '编辑个人题目' }}</h2><button class="icon-close" aria-label="关闭" @click="showEditor = false; resetForm()">×</button></div>
      <div class="qa-editor__grid">
        <label>关联课时
          <select v-model="form.lessonId"><option value="">不关联课时</option><option v-for="lesson in lessons" :key="lesson.id" :value="String(lesson.id)">{{ lesson.courseTitle }} · {{ lesson.moduleTitle }} · {{ lesson.title }}</option></select>
        </label>
        <label>题型
          <select v-model="form.qaType" @change="onTypeChange"><option value="CHOICE">选择题</option><option value="JUDGE">判断题</option><option value="SHORT_ANSWER">简答题</option></select>
        </label>
        <label>难度
          <select v-model="form.difficulty"><option value="EASY">简单</option><option value="MEDIUM">中等</option><option value="HARD">较难</option></select>
        </label>
        <label class="wide">题目<textarea v-model="form.question" rows="3" maxlength="512" placeholder="写清题目内容" /></label>
        <label v-if="form.qaType === 'CHOICE'" class="wide">选项（每行一个）<textarea v-model="form.optionsLines" rows="4" placeholder="A. 第一个选项&#10;B. 第二个选项" /></label>
        <label v-if="form.qaType === 'CHOICE'">正确选项
          <select v-model="form.answerKey"><option v-for="(_, i) in choiceOptions" :key="i" :value="String.fromCharCode(65 + i)">{{ String.fromCharCode(65 + i) }}</option></select>
        </label>
        <label v-else-if="form.qaType === 'JUDGE'">正确答案<select v-model="form.answerKey"><option value="TRUE">正确</option><option value="FALSE">错误</option></select></label>
        <label v-if="form.qaType === 'SHORT_ANSWER'" class="wide">参考答案<textarea v-model="form.answer" rows="3" placeholder="填写简答题参考答案" /></label>
        <label v-else class="wide">答案解析<textarea v-model="form.answer" rows="3" placeholder="说明判断依据或补充知识点（可选）" /></label>
      </div>
      <div class="qa-editor__actions"><button class="btn btn--ghost" @click="showEditor = false; resetForm()">取消</button><button class="btn btn--primary" :disabled="saving" @click="saveQuestion">{{ saving ? '保存中…' : '保存题目' }}</button></div>
      <p class="qa-editor__tip">个人题目仅自己可见。选择题选项和课时信息也支持在 CSV/JSON 中填写。</p>
    </section>

    <div v-if="loading" class="qa__loading"><div class="spinner" /></div>
    <div v-else-if="list.length" class="qa__list">
      <article v-for="(q, i) in list" :key="q.id" class="qitem card">
        <header class="qitem__head">
          <span class="qitem__no">{{ i + 1 }}</span>
          <span class="badge" :class="DIFF_BADGE[q.difficulty] || 'badge--sun'">{{ DIFF_LABEL[q.difficulty] || q.difficulty }}</span>
          <span class="badge badge--lilac">{{ typeLabel(q.qaType) }}</span>
          <span v-if="q.lessonTitle" class="badge badge--mint">{{ q.lessonTitle }}</span>
          <span v-else class="badge badge--sun">通用题</span>
          <span v-if="q.mine" class="qitem__owner">我的题目</span>
          <div v-if="q.mine" class="qitem__manage"><button class="text-button" @click="openEdit(q)">编辑</button><button class="text-button is-danger" @click="deleteQuestion(q)">删除</button></div>
        </header>
        <p class="qitem__text">{{ q.question }}</p>
        <ul v-if="parseOptions(q.options).length" class="qitem__options"><li v-for="(option, index) in parseOptions(q.options)" :key="index">{{ option }}</li></ul>
        <button class="btn btn--sm btn--mint qitem__btn" @click="revealed[q.id] = !revealed[q.id]">{{ revealed[q.id] ? '收起答案' : '看答案与解析' }}</button>
        <Transition name="expand"><div v-if="revealed[q.id]" class="qitem__answer">
          <p v-if="q.answer">{{ q.answer }}</p>
          <p v-if="q.answerKey" class="qitem__key">参考答案：{{ normalizeType(q.qaType) === 'JUDGE' ? judgeKey(q.answerKey) : q.answerKey }}</p>
          <p v-if="q.qaType === 'CODE'" class="qitem__legacy">这是旧版代码问答。如需编写并运行程序，请在代码挑战中创建对应任务。</p>
        </div></Transition>
      </article>
    </div>
    <section v-else class="card qa__empty">
      <div class="qa__empty-icon">✓</div>
      <h2>{{ filter === 'ALL' ? '题库刚刚起步' : '这个分类还没有题目' }}</h2>
      <p>可以手动创建题目，或导入 CSV / JSON。代码运行题请放到代码挑战，不会混进知识测验。</p>
      <div><button class="btn btn--primary" @click="openNew">新建一道题</button><button class="btn btn--ghost" @click="importInput?.click()">导入题目</button><RouterLink class="btn btn--ghost" to="/exercises">去做代码挑战</RouterLink></div>
    </section>
  </div>
</template>

<style scoped>
.qa{padding-top:var(--space-lg);padding-bottom:var(--space-xl)}
.qa__head{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;margin-bottom:18px}
.qa__title{margin:0;font-size:34px}.qa__sub{max-width:760px;margin:8px 0 0;color:var(--c-ink-faint);line-height:1.7}
.qa__actions,.qa__filters,.qa__tools,.qa-editor__actions,.qa__empty>div{display:flex;align-items:center;gap:9px}
.qa__tools{justify-content:space-between;margin-bottom:22px}.qa__filters{flex-wrap:wrap}.template-link,.text-button{border:0;background:none;color:var(--c-ink-soft);cursor:pointer;text-decoration:underline;text-underline-offset:3px}.template-link{font:inherit;font-size:13px}
.qa__notice,.qa__error{max-width:860px;margin:12px auto;padding:12px 16px;border-radius:12px}.qa__notice{background:var(--c-cream-deep);color:var(--c-ink)}.qa__error{background:#fff0ee;color:#8f3129}
.qa-import-preview{max-width:900px;margin:12px auto 22px;padding:20px}.qa-import-preview__head{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.qa-import-preview__head h2{margin:0 0 4px}.qa-import-preview__head p{margin:0;color:var(--c-ink-faint)}.qa-import-preview__rows{display:flex;flex-direction:column;gap:8px;margin-top:14px}.qa-import-preview__rows article{display:flex;justify-content:space-between;gap:16px;padding:10px 12px;border-radius:10px;background:var(--c-cream)}.qa-import-preview__rows article b{overflow:hidden;text-overflow:ellipsis}.qa-import-preview__rows article span{flex:none;color:var(--c-ink-faint);font-size:12px}.qa-import-preview__actions{display:flex;justify-content:flex-end;gap:9px;margin-top:16px}
.qa__loading{display:grid;place-items:center;padding:60px 0}.qa__list{display:flex;flex-direction:column;gap:15px;max-width:900px;margin:0 auto}
.qitem{padding:20px 24px}.qitem__head{display:flex;align-items:center;gap:9px;flex-wrap:wrap;margin-bottom:12px}.qitem__no{display:grid;place-items:center;width:30px;height:30px;font-family:var(--font-round);font-weight:700;background:var(--c-sun);border:var(--bw-thin) solid var(--c-line);border-radius:50%}.qitem__owner{font-size:12px;color:var(--c-mint)}.qitem__manage{display:flex;gap:12px;margin-left:auto}.text-button{font-size:13px}.text-button.is-danger{color:var(--c-coral-deep)}
.qitem__text{margin:0 0 12px;font-size:15.5px;line-height:1.85;font-weight:700}.qitem__options{margin:0 0 14px;padding-left:22px;color:var(--c-ink-soft);line-height:1.8}.qitem__btn{margin-bottom:4px}
.qitem__answer{margin-top:12px;padding:14px 18px;background:var(--c-cream-deep);border-left:6px solid var(--c-mint);border-radius:0 var(--radius-sm) var(--radius-sm) 0;animation:pop-in .28s both}.qitem__answer p{margin:0;font-size:14px;line-height:1.9}.qitem__key{margin-top:7px!important;font-weight:700;color:var(--c-coral-deep)}.qitem__legacy{margin-top:8px!important;color:var(--c-ink-faint)}
.qa-editor{max-width:900px;margin:0 auto 22px;padding:22px}.qa-editor__head{display:flex;align-items:center;justify-content:space-between}.qa-editor__head h2{margin:0 0 16px}.icon-close{width:34px;height:34px;margin-top:-12px;border:1px solid var(--c-line);border-radius:50%;background:var(--c-paper);color:var(--c-ink);font-size:22px;cursor:pointer}.qa-editor__grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.qa-editor__grid label{display:flex;flex-direction:column;gap:6px;font-weight:700;color:var(--c-ink)}.qa-editor__grid .wide{grid-column:1/-1}.qa-editor select,.qa-editor textarea{width:100%;padding:10px 12px;border:1px solid var(--c-line);border-radius:10px;background:var(--c-paper);color:var(--c-ink);font:inherit;font-weight:400}.qa-editor__actions{justify-content:flex-end;margin-top:16px}.qa-editor__tip{margin:12px 0 0;color:var(--c-ink-faint);font-size:13px}
.qa__empty{max-width:760px;margin:50px auto;padding:36px;text-align:center}.qa__empty-icon{display:grid;place-items:center;width:52px;height:52px;margin:0 auto 14px;border:2px solid var(--c-mint);border-radius:50%;font-size:26px;color:var(--c-mint)}.qa__empty h2{margin:0 0 8px}.qa__empty p{max-width:560px;margin:0 auto 20px;color:var(--c-ink-soft);line-height:1.7}.qa__empty>div{justify-content:center;flex-wrap:wrap}
.expand-enter-active,.expand-leave-active{transition:opacity .2s,max-height .24s;overflow:hidden}.expand-enter-from,.expand-leave-to{opacity:0;max-height:0}.expand-enter-to,.expand-leave-from{max-height:500px}
@media(max-width:760px){.qa__head{align-items:flex-start;flex-direction:column}.qa__actions{flex-wrap:wrap}.qa__tools{align-items:flex-start;flex-direction:column}.qa-editor__grid{grid-template-columns:1fr}.qa-editor__grid .wide{grid-column:auto}.qitem{padding:18px}.qitem__manage{width:100%;margin-left:39px}.qa-import-preview__rows article{align-items:flex-start;flex-direction:column;gap:4px}}
</style>
