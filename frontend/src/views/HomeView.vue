<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { courseApi, type CourseModule } from '@/api'
import { useAgentStore } from '@/stores/agent'
import { useProgressStore } from '@/stores/progress'

const courseSlug = 'java-mastery'
const firstLesson = { slug: 'hello-world' }
const courseRoute = { name: 'course', params: { slug: courseSlug } }
const firstLessonRoute = { name: 'lesson', params: firstLesson }
const labRoute = { name: 'lesson-lab', params: firstLesson }
const assistantImage = import.meta.env.BASE_URL + 'assets/agent/agent-idle.png'

const modules = ref<CourseModule[]>([])
const loadFailed = ref(false)
const agent = useAgentStore()
const progress = useProgressStore()

const lessons = computed(() => modules.value.flatMap((module) => module.lessons ?? []))
const courseStats = computed(() => [
  { label: '模块', count: modules.value.length },
  { label: '课时', count: lessons.value.length },
])
const lastLesson = computed(() => progress.items.find((item) =>
  lessons.value.some((lesson) => lesson.id === item.lessonId),
))
const entryLesson = computed(() => {
  const recent = lastLesson.value
  if (!recent || !recent.completed) return recent
  const recentIndex = lessons.value.findIndex((lesson) => lesson.id === recent.lessonId)
  return lessons.value.slice(recentIndex + 1).find((lesson) => !progress.isCompleted(lesson.id))
    ?? lessons.value.find((lesson) => !progress.isCompleted(lesson.id))
    ?? recent
})
const entryLabel = computed(() => {
  if (!entryLesson.value) return '开始学习'
  return entryLesson.value === lastLesson.value && lastLesson.value.completed ? '复习课时' : '继续学习'
})
const entryRoute = computed(() => entryLesson.value
  ? {
      name: 'lesson',
      params: { slug: entryLesson.value.slug },
      query: entryLabel.value === '继续学习' ? { resume: '1' } : {},
    }
  : firstLessonRoute,
)

const links = [
  { to: courseRoute, icon: '☷', title: '课程目录', description: '按模块浏览课时、笔记和配套练习。' },
  { to: { name: 'learning-videos' }, icon: '▷', title: '学习视频', description: '按课时查找配套讲解，跟着视频学。' },
  { to: { name: 'exercises' }, icon: '{ }', title: '代码练习', description: '选择编程题，编写代码并查看判题结果。' },
]

async function loadCourse() {
  loadFailed.value = false
  try {
    const detail = await courseApi.detail(courseSlug)
    modules.value = detail.modules ?? []
  } catch {
    loadFailed.value = true
  }
}

onMounted(() => {
  void loadCourse()
  void progress.load().catch(() => {})
})
</script>

<template>
  <div class="container home">
    <section class="hero" aria-labelledby="home-title">
      <div class="hero__intro">
        <h1 id="home-title">Java 精通之路</h1>
        <p class="hero__description">
          从第一个 Java 程序出发，逐步学习面向对象、集合、JVM、并发和框架实战。读课时笔记、看配套视频，再动手编写和运行代码。
        </p>
        <div class="home__actions">
          <RouterLink :to="entryRoute" class="home-button home-button--primary">
            {{ entryLabel }} <span aria-hidden="true">→</span>
          </RouterLink>
          <RouterLink :to="courseRoute" class="home-button">查看课程目录</RouterLink>
        </div>
        <p v-if="entryLesson" class="hero__detail">
          {{ entryLabel === '复习课时' ? '复习' : '接下来' }} · {{ entryLesson.title }}
        </p>
        <div v-else-if="loadFailed" class="hero__detail">
          <span role="status">暂时无法读取续学课时。</span>
          <button type="button" class="home-text-button" @click="loadCourse">重试</button>
        </div>
      </div>

      <aside class="course-overview" aria-labelledby="course-overview-title">
        <h2 id="course-overview-title">课程概览</h2>
        <dl v-if="lessons.length" class="course-overview__stats">
          <div v-for="stat in courseStats" :key="stat.label">
            <dt>{{ stat.label }}</dt>
            <dd>{{ stat.count }}</dd>
          </div>
        </dl>
        <p>适合初学者，也可按模块复习。</p>
        <RouterLink :to="{ name: 'learning-center' }">查看我的学习进度 <span aria-hidden="true">→</span></RouterLink>
      </aside>
    </section>

    <section class="home__section" aria-labelledby="home-entry-title">
      <h2 id="home-entry-title">学习入口</h2>
      <div class="entry-grid">
        <RouterLink v-for="link in links" :key="link.title" :to="link.to" class="entry-card">
          <span class="entry-card__icon" aria-hidden="true">{{ link.icon }}</span>
          <span class="entry-card__title">{{ link.title }} <span aria-hidden="true">↗</span></span>
          <span class="entry-card__description">{{ link.description }}</span>
        </RouterLink>
        <button
          type="button"
          class="entry-card"
          :aria-expanded="agent.panelOpen"
          aria-controls="agent-drawer"
          @click="agent.open()"
        >
          <span class="entry-card__icon"><img :src="assistantImage" alt="" width="30" height="30" /></span>
          <span class="entry-card__title">鲸鲸助教 <span aria-hidden="true">↗</span></span>
          <span class="entry-card__description">带着概念或编译报错向助教提问。</span>
        </button>
      </div>
    </section>

    <section class="featured home__section" aria-labelledby="home-featured-title">
      <div class="featured__intro">
        <p class="featured__label">体验课</p>
        <h2 id="home-featured-title">运行你的第一个 Java 程序</h2>
        <p>跟着 HelloWorld 视频写出第一个程序，修改输出文字，再运行一次看看结果。</p>
        <div class="home__actions">
          <RouterLink :to="labRoute" class="home-button home-button--primary">边看边练 <span aria-hidden="true">→</span></RouterLink>
          <RouterLink :to="firstLessonRoute" class="home-text-button">阅读课时笔记</RouterLink>
        </div>
      </div>
      <dl class="featured__goals">
        <div>
          <dt>读笔记</dt>
          <dd>理解知识点，先预测示例会怎样运行。</dd>
        </div>
        <div>
          <dt>动手练</dt>
          <dd>跟着配套视频修改代码，对照运行结果。</dd>
        </div>
        <div>
          <dt>问助教</dt>
          <dd>带上你的思路和报错，请鲸鲸帮你找原因。</dd>
        </div>
      </dl>
    </section>
  </div>
</template>

<style scoped>
.home {
  --home-border: #d9d9e5;
  --home-surface: #fffdf9;
  padding-top: clamp(20px, 3vw, 40px);
}

.hero {
  display: grid;
  grid-template-columns: minmax(0, 1.5fr) minmax(0, 1fr);
  gap: clamp(24px, 5vw, 64px);
  align-items: center;
  padding: clamp(24px, 4.4vw, 56px);
  border: 1px solid var(--home-border);
  border-top: 4px solid var(--c-ink);
  border-radius: var(--radius-lg);
  background: linear-gradient(114deg, var(--home-surface) 57%, #f6f3fd);
  box-shadow: 0 9px 24px rgba(45, 53, 97, .06);
}

.featured__label {
  margin: 0 0 14px;
  color: #4f487e;
  font-size: .875rem;
  font-weight: 800;
  letter-spacing: .08em;
}
.hero h1 {
  margin: 0;
  font-size: clamp(2.125rem, 4.1vw, 3.625rem);
  font-weight: 850;
  letter-spacing: -.045em;
  line-height: 1.16;
}
.hero__description, .featured__intro > p:not(.featured__label) {
  max-width: 35em;
  margin: 16px 0 22px;
  color: var(--c-ink-soft);
  line-height: 1.75;
}
.home__actions { display: flex; flex-wrap: wrap; align-items: center; gap: 10px 14px; }
.home-button {
  display: inline-flex;
  min-height: 44px;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 9px 16px;
  border: 1px solid #898bad;
  border-radius: 9px;
  background: var(--c-paper);
  color: var(--c-ink);
  font-size: .9375rem;
  font-weight: 750;
  text-decoration: none;
}
.home-button:hover { background: #f1eefb; }
.home-button--primary { border-color: var(--c-ink); background: var(--c-ink); color: #fff; }
.home-button--primary:hover { background: #414b82; }
.hero__detail { margin: 12px 0 0; color: var(--c-ink-soft); font-size: .875rem; }
.home-text-button {
  padding: 6px 4px;
  border: 0;
  background: transparent;
  color: var(--c-ink);
  font: inherit;
  font-weight: 700;
  text-underline-offset: .22em;
  text-decoration: underline;
  cursor: pointer;
}
.home :is(a, button):focus-visible { outline: 3px solid #7253c5; outline-offset: 3px; }

.course-overview {
  padding: clamp(20px, 3vw, 32px);
  border: 1px solid #dfd9ee;
  border-radius: var(--radius-md);
  background: #f0ecf9;
}
.course-overview h2 { margin: 0; font-size: 1.125rem; }
.course-overview__stats {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin: 18px 0 0;
}
.course-overview__stats > div {
  display: flex;
  flex-direction: column-reverse;
  gap: 2px;
  padding: 12px 14px;
  border-radius: 10px;
  background: var(--home-surface);
}
.course-overview__stats dt, .course-overview p { color: var(--c-ink-soft); font-size: .875rem; }
.course-overview__stats dd {
  margin: 0;
  font-family: var(--font-round);
  font-size: clamp(1.625rem, 3vw, 2.125rem);
  font-weight: 800;
  line-height: 1.1;
}
.course-overview p { margin: 16px 0 10px; line-height: 1.5; }
.course-overview a { color: var(--c-ink); font-size: .875rem; font-weight: 700; text-underline-offset: .22em; }

.home__section { margin-top: clamp(24px, 3vw, 38px); }
.home__section h2 { margin: 0 0 14px; font-size: clamp(1.375rem, 2.4vw, 1.875rem); }
.entry-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px; }
.entry-card {
  display: grid;
  align-content: start;
  gap: 7px;
  min-width: 0;
  padding: 18px;
  border: 1px solid var(--home-border);
  border-radius: var(--radius-md);
  background: var(--home-surface);
  color: var(--c-ink);
  font: inherit;
  text-align: left;
  text-decoration: none;
  cursor: pointer;
}
.entry-card:hover { border-color: #8c88b1; background: #faf7ff; }
.entry-card__icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 9px;
  background: #ece9fa;
  font: 750 1.125rem var(--font-mono);
}
.entry-card:nth-child(2) .entry-card__icon { background: #fceadc; }
.entry-card:nth-child(3) .entry-card__icon { background: #dff3ee; }
.entry-card:nth-child(4) .entry-card__icon { background: #f9edca; }
.entry-card__icon img { object-fit: contain; }
.entry-card__title { display: flex; justify-content: space-between; gap: 6px; font-weight: 800; }
.entry-card__title > span { color: var(--c-ink-soft); }
.entry-card__description { color: var(--c-ink-soft); font-size: .875rem; line-height: 1.6; }

.featured {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  gap: clamp(16px, 4vw, 50px);
  padding: clamp(22px, 3vw, 38px);
  border: 1px solid #ccdcd8;
  border-radius: var(--radius-lg);
  background: #edf6f2;
}
.featured__label { margin-bottom: 8px; }
.featured__intro > p:not(.featured__label) { margin: 0 0 18px; }
.featured__goals {
  margin: 0;
  padding: 0;
  border-top: 1px solid #ccdcd8;
}
.featured__goals > div {
  display: grid;
  grid-template-columns: 5.25em minmax(0, 1fr);
  gap: 8px;
  padding: 12px 0;
  border-bottom: 1px solid #ccdcd8;
}
.featured__goals dt { font-weight: 800; }
.featured__goals dd { margin: 0; color: var(--c-ink-soft); font-size: .875rem; line-height: 1.55; }

@media (max-width: 820px) {
  .hero, .featured { grid-template-columns: 1fr; }
  .entry-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 480px) {
  .home { padding-inline: 14px; }
  .hero { padding: 20px 16px; }
  .hero h1 { font-size: clamp(1.75rem, 8.4vw, 2.375rem); }
  .entry-card { padding: 12px; }
  .entry-grid { gap: 10px; }
  .featured { padding: 18px 16px; }
}
</style>
