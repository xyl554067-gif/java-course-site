<script setup lang="ts">
import { computed, ref, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { courseApi, type Course, type CourseModule } from '@/api'
import EncapsulationCourse from '@/components/EncapsulationCourse.vue'
import { useAgentStore } from '@/stores/agent'
import { useProgressStore } from '@/stores/progress'
import { errMsg } from '@/api/http'

const route = useRoute()
const agent = useAgentStore()
const progress = useProgressStore()

const course = ref<Course | null>(null)
const modules = ref<CourseModule[]>([])
const videoLessonIds = ref<number[]>([])
const loading = ref(true)
const error = ref('')
const openModules = ref<Record<number, boolean>>({})
const topicSlug = 'java-encapsulation'
const topicCourse = ref<Course>()
const lessons = computed(() => modules.value.flatMap(module => module.lessons ?? []))
let loadVersion = 0

const ICONS: Record<string, string> = {
  coffee: '☕',
  puzzle: '🧩',
  boxes: '🗃️',
  compass: '🧭',
  rocket: '🚀',
  code: '💻',
}

async function load(slug: string) {
  const version = ++loadVersion
  loading.value = true
  error.value = ''
  course.value = null
  modules.value = []
  videoLessonIds.value = []
  openModules.value = {}
  try {
    const detail = await courseApi.detail(slug)
    if (version !== loadVersion) return
    // 后端把课程信息平铺在顶层，modules 为其兄弟键
    course.value = (detail.course || detail) as Course
    modules.value = detail.modules || []
    videoLessonIds.value = detail.videoLessonIds || []
    modules.value.forEach((m) => (openModules.value[m.id] = true))
  } catch (e) {
    if (version === loadVersion) error.value = errMsg(e)
  } finally {
    if (version === loadVersion) loading.value = false
  }
}

watch(() => route.params.slug, (slug) => {
  void load(String(slug))
  if (slug === 'java-mastery' && !topicCourse.value) {
    void courseApi.list().then(list => {
      topicCourse.value = list.find(item => item.slug === topicSlug)
    }).catch(() => {})
  }
}, { immediate: true })

onMounted(() => {
  void progress.load().catch(() => {})
})
</script>

<template>
  <div class="container cview">
    <div v-if="loading" class="cview__loading"><div class="spinner" /></div>
    <div v-else-if="error" class="card cview__error" role="alert">
      <p>{{ error }}</p>
      <button type="button" class="btn btn--primary" @click="load(String(route.params.slug))">重试加载课程</button>
    </div>

    <EncapsulationCourse v-else-if="course?.slug === topicSlug"
      :course="course" :lessons="lessons" :video-lesson-ids="videoLessonIds" />

    <template v-else-if="course">
      <header class="cview__hero card anim-pop">
        <span class="cview__crumb"><RouterLink to="/">← 返回首页</RouterLink></span>
        <h1 class="title-round cview__title">{{ course.title }}</h1>
        <p class="cview__sub">{{ course.subtitle }}</p>
        <p class="cview__desc">{{ course.description }}</p>
        <div class="cview__tags">
          <span class="badge badge--coral">{{ course.version }}</span>
          <span class="badge badge--mint">{{ course.totalLessons }} 课时</span>
          <span class="badge badge--sun">{{ modules.length }} 模块</span>
          <span class="badge badge--lilac">{{ course.instructor }}</span>
          <RouterLink class="btn btn--sm btn--ghost" :to="{ name: 'learning-videos' }">学习视频</RouterLink>
          <RouterLink class="btn btn--sm btn--ghost" :to="{ name: 'resources' }">资料库</RouterLink>
        </div>
      </header>

      <aside v-if="course.slug === 'java-mastery' && topicCourse" class="course-topic">
        <div>
          <p>专题课程</p>
          <h2>{{ topicCourse.title }}</h2>
          <span>{{ topicCourse.subtitle }}</span>
        </div>
        <RouterLink :to="{ name: 'course', params: { slug: topicSlug } }" class="btn btn--sm btn--ghost">查看专题 →</RouterLink>
      </aside>

      <div class="cview__tree">
        <article v-for="(m, mi) in modules" :key="m.id" class="cmod card">
          <header class="cmod__head" @click="openModules[m.id] = !openModules[m.id]">
            <span class="cmod__icon">{{ ICONS[m.icon] || '📘' }}</span>
            <div class="cmod__meta">
              <h2 class="title-round cmod__title">
                <span class="cmod__no">{{ String(mi + 1).padStart(2, '0') }}</span>{{ m.title }}
              </h2>
              <p class="cmod__sum">{{ m.summary }}</p>
            </div>
            <span class="badge badge--mint">{{ m.lessonCount }} 节</span>
            <span class="cmod__arrow" :class="{ 'is-open': openModules[m.id] }">▾</span>
          </header>

          <Transition name="expand">
            <ul v-if="openModules[m.id]" class="cmod__lessons">
              <li v-for="(l, li) in m.lessons || []" :key="l.id">
                <RouterLink :to="`/lesson/${l.slug}`" class="clink">
                  <span class="clink__no" :aria-label="progress.isCompleted(l.id) ? '已完成' : undefined">{{ progress.isCompleted(l.id) ? '✓' : li + 1 }}</span>
                  <span class="clink__title">
                    {{ l.title }}
                    <small v-if="progress.progressOf(l.id)?.selfCheckStage === 2" class="badge badge--mint">自测通过</small>
                    <small v-if="progress.progressOf(l.id)?.progressPct" class="clink__reading">已读 {{ progress.progressOf(l.id)?.progressPct }}%</small>
                  </span>
                  <span class="clink__sum">{{ l.summary }}</span>
                  <span class="clink__go">→</span>
                </RouterLink>
                <RouterLink v-if="videoLessonIds.includes(l.id)" class="btn btn--sm btn--ghost clink-video"
                  :to="{ name: 'lesson-lab', params: { slug: l.slug } }">边看边练</RouterLink>
              </li>
            </ul>
          </Transition>

          <footer class="cmod__foot">
            <button
              class="btn btn--sm btn--ghost"
              @click="agent.open(); agent.ask(`「${m.title}」模块的学习重点是什么？`)"
            >
              🐳 让鲸鲸梳理这个模块
            </button>
          </footer>
        </article>
      </div>
    </template>
  </div>
</template>

<style scoped>
.clink-video { margin: 0 0 8px 14px; }
.clink__reading { margin-left: 6px; color: var(--c-ink-soft); font-weight: 400; }
.cview { padding-top: var(--space-lg); }
.cview__loading { display: grid; place-items: center; padding: 70px 0; }
.cview__error { padding: 24px; }
.cview__error p { margin: 0 0 16px; }

.cview__hero { padding: 32px; margin-bottom: 24px; background: linear-gradient(135deg, var(--c-paper) 60%, var(--c-cream-deep)); }
.cview__crumb { display: inline-block; margin-bottom: 10px; font-size: 13px; }
.cview__crumb a { color: var(--c-ink-faint); text-decoration: none; }
.cview__crumb a:hover { color: var(--c-coral); }
.cview__title { margin: 0 0 8px; font-size: 34px; }
.cview__sub { margin: 0 0 12px; font-size: 16px; font-weight: 700; color: var(--c-coral-deep); }
.cview__desc { margin: 0 0 16px; font-size: 14.5px; line-height: 1.9; color: var(--c-ink-soft); }
.cview__tags { display: flex; gap: 8px; flex-wrap: wrap; }

.course-topic {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 22px;
  padding: 15px 18px;
  border: 1px solid #c6b9e3;
  border-radius: var(--radius-md);
  background: #f4efff;
  color: var(--c-ink);
}
.course-topic p { margin: 0 0 3px; color: #514181; font-size: .77rem; font-weight: 750; }
.course-topic h2 { margin: 0 0 4px; font-size: 1.12rem; }
.course-topic span { color: var(--c-ink-soft); font-size: .86rem; }

.cview__tree { display: flex; flex-direction: column; gap: 18px; }
.cmod { overflow: hidden; }
.cmod__head { display: flex; align-items: center; gap: 16px; padding: 20px 22px; cursor: pointer; }
.cmod__icon {
  width: 50px; height: 50px;
  display: grid; place-items: center;
  font-size: 25px;
  background: var(--c-sun);
  border: var(--bw-base) solid var(--c-line);
  border-radius: var(--radius-md);
  flex-shrink: 0;
}
.cmod__meta { flex: 1; min-width: 0; }
.cmod__title { margin: 0 0 4px; font-size: 20px; }
.cmod__no { margin-right: 8px; font-size: 14px; color: var(--c-coral); }
.cmod__sum { margin: 0; font-size: 13px; color: var(--c-ink-faint); }
.cmod__arrow { font-size: 20px; color: var(--c-ink-faint); transition: transform .2s; }
.cmod__arrow.is-open { transform: rotate(180deg); color: var(--c-coral); }

.cmod__lessons {
  margin: 0; padding: 12px 22px 8px;
  list-style: none;
  border-top: var(--bw-thin) dashed var(--c-ink-faint);
}
.clink {
  display: grid;
  grid-template-columns: 34px 1.2fr 2fr 24px;
  align-items: center;
  gap: 12px;
  padding: 11px 14px;
  margin-bottom: 6px;
  text-decoration: none;
  color: var(--c-ink);
  background: var(--c-cream);
  border: var(--bw-thin) solid transparent;
  border-radius: var(--radius-md);
  transition: all .16s;
}
.clink:hover { background: var(--c-sun); border-color: var(--c-line); transform: translateX(4px); box-shadow: var(--shadow-sm); }
.clink__no {
  display: grid; place-items: center;
  width: 28px; height: 28px;
  font-family: var(--font-round); font-size: 13px; font-weight: 700;
  background: var(--c-paper);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: 50%;
}
.clink__title { font-family: var(--font-round); font-weight: 700; }
.clink__sum { font-size: 12px; color: var(--c-ink-faint); }
.clink__go { color: var(--c-coral); font-weight: 700; }
.cmod__foot { padding: 0 22px 18px; }

.expand-enter-active, .expand-leave-active { transition: opacity .2s, max-height .25s; overflow: hidden; }
.expand-enter-from, .expand-leave-to { opacity: 0; max-height: 0; }
.expand-enter-to, .expand-leave-from { max-height: 900px; }

@media (max-width: 900px) {
  .clink { grid-template-columns: 30px 1fr 20px; }
  .clink__sum { display: none; }
  .cview__title { font-size: 26px; }
}
</style>
