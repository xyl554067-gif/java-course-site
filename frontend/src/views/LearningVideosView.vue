<script setup lang="ts">
import { computed, nextTick, onMounted, ref } from 'vue'
import { courseApi, learningVideoApi, type LearningVideo, type VideoInput, type QaLessonOption } from '@/api'
import { errMsg } from '@/api/http'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const videos = ref<LearningVideo[]>([])
const lessons = ref<QaLessonOption[]>([])
const loading = ref(true)
const saving = ref(false)
const loadError = ref('')
const editError = ref('')
const notice = ref('')
const editingId = ref<number>()
const draft = ref<VideoInput>()
const formHeading = ref<HTMLHeadingElement | null>(null)
const removingId = ref<number>()

const courses = computed(() => {
  const groups = new Map<string, { title: string; videos: LearningVideo[] }>()
  for (const video of videos.value) {
    const group = groups.get(video.courseSlug) ?? { title: video.courseTitle, videos: [] }
    group.videos.push(video)
    groups.set(video.courseSlug, group)
  }
  return groups
})

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    videos.value = await learningVideoApi.list()
  } catch (e) {
    loadError.value = errMsg(e)
  } finally {
    loading.value = false
  }
}

async function edit(video?: LearningVideo) {
  notice.value = ''
  editError.value = ''
  removingId.value = undefined
  editingId.value = video?.id
  draft.value = {
    url: video?.sourceUrl ?? '',
    title: video?.title ?? '',
    uploader: video?.uploader ?? '',
    lessonId: video?.lessonId ?? 0,
    label: video?.label ?? '',
    partNumber: video?.partNumber ?? 1,
    startSeconds: video?.startSeconds ?? 0,
    recommendation: video?.recommendation ?? '',
    sortOrder: video?.sortOrder ?? 0,
  }
  await nextTick()
  formHeading.value?.focus()
  if (!lessons.value.length) {
    try {
      lessons.value = await courseApi.qaLessons()
    } catch (e) {
      editError.value = errMsg(e)
    }
  }
}

function fillLinkPosition() {
  if (!draft.value) return
  try {
    const params = new URL(draft.value.url).searchParams
    const part = Number(params.get('p'))
    const start = Number(params.get('t'))
    if (Number.isInteger(part) && part >= 1) draft.value.partNumber = part
    if (params.has('t') && Number.isInteger(start) && start >= 0) draft.value.startSeconds = start
  } catch {
    // The form and API validate the URL on save.
  }
}

async function save() {
  if (!draft.value || saving.value) return
  saving.value = true
  editError.value = ''
  try {
    await learningVideoApi.save(draft.value, editingId.value)
    draft.value = undefined
    notice.value = '视频已保存。'
    await load()
  } catch (e) {
    editError.value = errMsg(e)
  } finally {
    saving.value = false
  }
}

async function remove(id: number) {
  if (saving.value) return
  saving.value = true
  editError.value = ''
  try {
    await learningVideoApi.remove(id)
    removingId.value = undefined
    notice.value = '已从该课时移除视频。'
    if (editingId.value === id) draft.value = undefined
    await load()
  } catch (e) {
    editError.value = errMsg(e)
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <main class="container videos-page">
    <header class="videos-head">
      <h1 class="title-round">学习视频</h1>
      <button v-if="auth.isAdmin" class="btn btn--primary" :disabled="saving" @click="edit()">添加视频</button>
    </header>
    <p v-if="notice" role="status">{{ notice }}</p>
    <p v-if="editError" role="alert">{{ editError }}</p>

    <form v-if="auth.isAdmin && draft" class="card video-form" @submit.prevent="save">
      <h2 ref="formHeading" tabindex="-1">{{ editingId ? '编辑课时视频' : '添加课时视频' }}</h2>
      <p>原视频标题和 UP 主会同步到引用同一 BV 号的课时。</p>
      <fieldset :disabled="saving">
        <label class="wide">B 站原链接
          <input v-model.trim="draft.url" type="url" placeholder="https://www.bilibili.com/video/BV…" required @change="fillLinkPosition" />
        </label>
        <label>原视频标题<input v-model.trim="draft.title" maxlength="160" required /></label>
        <label>UP 主<input v-model.trim="draft.uploader" maxlength="100" required /></label>
        <label class="wide">对应课时
          <select v-model.number="draft.lessonId" required>
            <option :value="0" disabled>选择课时</option>
            <option v-for="lesson in lessons" :key="lesson.id" :value="lesson.id">{{ lesson.courseTitle }} · {{ lesson.title }}</option>
          </select>
        </label>
        <label class="wide">课时内标题<input v-model.trim="draft.label" maxlength="160" required /></label>
        <label>分集<input v-model.number="draft.partNumber" type="number" min="1" max="2147483647" required /></label>
        <label>起始秒数<input v-model.number="draft.startSeconds" type="number" min="0" max="2147483647" required /></label>
        <label>排序<input v-model.number="draft.sortOrder" type="number" min="0" max="2147483647" required /></label>
        <label class="wide">推荐理由<textarea v-model.trim="draft.recommendation" rows="2" maxlength="512" /></label>
      </fieldset>
      <div class="video-actions">
        <button class="btn btn--primary" type="submit" :disabled="saving || !draft.lessonId">保存</button>
        <button class="btn btn--ghost" type="button" :disabled="saving" @click="draft = undefined; editError = ''">取消</button>
      </div>
    </form>

    <p v-if="loading" role="status">正在加载学习视频…</p>
    <p v-else-if="loadError" role="alert">{{ loadError }} <button class="btn btn--sm btn--ghost" @click="load">重试</button></p>
    <p v-else-if="!videos.length">暂时没有学习视频。</p>
    <template v-else>
      <section v-for="[slug, course] in courses" :key="slug" class="video-course">
        <h2><RouterLink :to="{ name: 'course', params: { slug } }">{{ course.title }}</RouterLink></h2>
        <ul>
          <li v-for="video in course.videos" :key="video.id" class="card video-item">
            <div>
              <h3>{{ video.label }}</h3>
              <p>{{ video.lessonTitle }} · {{ video.uploader }} · B 站第 {{ video.partNumber }} 集</p>
              <p v-if="video.recommendation">{{ video.recommendation }}</p>
            </div>
            <div class="video-actions">
              <RouterLink class="btn btn--primary" :to="{ name: 'lesson-lab', params: { slug: video.lessonSlug }, query: { video: String(video.id) } }">边看边练</RouterLink>
              <template v-if="auth.isAdmin">
                <button class="btn btn--ghost" :disabled="saving" @click="edit(video)">编辑</button>
                <button v-if="removingId !== video.id" class="btn btn--ghost" :disabled="saving" @click="removingId = video.id">移除</button>
                <template v-else>
                  <button class="btn btn--ghost" :disabled="saving" @click="remove(video.id)">确认移除</button>
                  <button class="btn btn--ghost" :disabled="saving" @click="removingId = undefined">取消</button>
                </template>
              </template>
            </div>
          </li>
        </ul>
      </section>
    </template>
  </main>
</template>

<style scoped>
.videos-page { padding: 28px 0; }
.videos-head, .video-actions { display: flex; align-items: center; gap: 10px; }
.videos-head { justify-content: space-between; flex-wrap: wrap; }
.video-item { display: grid; gap: 12px; }
.videos-head h1, .video-item h3 { margin: 0; }
.video-item p { margin: 5px 0 0; color: var(--c-ink-soft); }
.video-course ul { list-style: none; padding: 0; display: grid; gap: 12px; }
.video-item, .video-form { padding: 18px; }
.video-form { margin: 16px 0; max-width: 720px; }
.video-form h2 { margin-top: 0; scroll-margin-top: calc(var(--nav-h) + 12px); }
.video-form > p { color: var(--c-ink-soft); }
.video-form fieldset { border: 0; padding: 0; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; margin: 0 0 14px; }
.video-form label { display: grid; gap: 4px; }
.video-form input, .video-form select, .video-form textarea { width: 100%; min-width: 0; font: inherit; color: var(--c-ink); padding: 8px; border: 1px solid var(--c-line); border-radius: 8px; }
.wide { grid-column: 1 / -1; }
.video-actions { flex-wrap: wrap; }
</style>
