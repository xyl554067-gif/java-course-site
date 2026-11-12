<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { courseApi, type CourseModule } from '@/api'
import { useAgentStore } from '@/stores/agent'
import { useProgressStore } from '@/stores/progress'

const courseSlug = 'java-mastery'
const topicLesson = { slug: 'oop-core' }
const courseRoute = { name: 'course', params: { slug: courseSlug } }
const topicRoute = { name: 'lesson', params: topicLesson }
const labRoute = { name: 'lesson-lab', params: topicLesson }
const assistantImage = import.meta.env.BASE_URL + 'assets/agent/agent-idle.png'

const modules = ref<CourseModule[]>([])
const loadFailed = ref(false)
const agent = useAgentStore()
const progress = useProgressStore()

const lessons = computed(() => modules.value.flatMap((module) => module.lessons ?? []))
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
  if (!entryLesson.value) return '开始专题学习'
  return entryLesson.value === lastLesson.value && lastLesson.value.completed ? '复习课时' : '继续学习'
})
const entryRoute = computed(() => entryLesson.value
  ? {
      name: 'lesson',
      params: { slug: entryLesson.value.slug },
      query: entryLabel.value === '继续学习' ? { resume: '1' } : {},
    }
  : topicRoute,
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
        <p class="hero__site">Java 精通之路 · 课程专题</p>
        <h1 id="home-title">封装、访问控制<br />与包管理</h1>
        <p class="hero__description">
          从一个账户类入手，学习怎样保护对象的数据、控制谁能访问类的成员，以及用包组织 Java 代码。
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

      <figure class="example">
        <figcaption class="example__header">
          <span>Account.java</span>
          <span class="example__language">Java</span>
        </figcaption>
        <pre><code><span class="example__keyword">package</span> demo.bank;

<span class="example__keyword">public class</span> <span class="example__type">Account</span> {
    <span class="example__keyword">private int</span> balance;

    <span class="example__keyword">public void</span> <span class="example__method">deposit</span>(<span class="example__keyword">int</span> amount) {
        <span class="example__keyword">if</span> (amount &gt; <span class="example__literal">0</span>) {
            balance += amount;
        }
    }
}</code></pre>
        <p class="example__note">试着解释为什么外部类可以调用 <code>deposit</code>，却不能直接修改 <code>balance</code>。</p>
      </figure>
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
        <p class="featured__label">专题体验课</p>
        <h2 id="home-featured-title">封装、继承与多态</h2>
        <p>打开课时笔记，或进入实验室观看「封装」分集，在视频旁编辑并运行 Java。</p>
        <div class="home__actions">
          <RouterLink :to="labRoute" class="home-button home-button--primary">边看边练 <span aria-hidden="true">→</span></RouterLink>
          <RouterLink :to="topicRoute" class="home-text-button">阅读课时笔记</RouterLink>
        </div>
      </div>
      <dl class="featured__goals">
        <div>
          <dt>封装</dt>
          <dd>把字段设为 <code>private</code>，在公开方法里校验输入。</dd>
        </div>
        <div>
          <dt>访问控制</dt>
          <dd>比较同包类、异包类和异包子类可以访问哪些成员。</dd>
        </div>
        <div>
          <dt>包管理</dt>
          <dd>用 <code>package</code> 声明所属包，用 <code>import</code> 引用其他包中的可访问类型。</dd>
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
  grid-template-columns: minmax(0, 1.12fr) minmax(0, 1fr);
  gap: clamp(24px, 5vw, 64px);
  align-items: center;
  padding: clamp(24px, 4.4vw, 56px);
  border: 1px solid var(--home-border);
  border-top: 4px solid var(--c-ink);
  border-radius: var(--radius-lg);
  background: linear-gradient(114deg, var(--home-surface) 57%, #f6f3fd);
  box-shadow: 0 9px 24px rgba(45, 53, 97, .06);
}

.hero__site, .featured__label {
  margin: 0 0 14px;
  color: #4f487e;
  font-size: .875rem;
  font-weight: 800;
  letter-spacing: .08em;
}
.hero__site::before {
  display: inline-block;
  width: 20px;
  height: 3px;
  margin-right: 10px;
  vertical-align: middle;
  background: var(--c-sun-deep);
  content: '';
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

.example {
  min-width: 0;
  margin: 0;
  overflow: hidden;
  border-radius: var(--radius-md);
  background: #212743;
  color: #eef0ff;
  box-shadow: 0 14px 30px rgba(33, 39, 67, .2);
}
.example__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 13px 20px;
  border-bottom: 1px solid #474e71;
  background: #2c3457;
  font: 600 .875rem var(--font-mono);
}
.example__language { color: #c5cce9; font-size: .75rem; }
.example pre {
  margin: 0;
  padding: 16px 20px;
  overflow-x: auto;
  font: clamp(.75rem, 1.1vw, .875rem)/1.52 var(--font-mono);
  tab-size: 4;
}
.example code, .featured__goals code { font-family: var(--font-mono); }
.example__keyword { color: #d4c3ff; }
.example__type { color: #ffd888; }
.example__method { color: #8ce5cf; }
.example__literal { color: #ffd888; }
.example__note {
  margin: 0;
  padding: 12px 20px;
  border-top: 1px solid #474e71;
  color: #d6dcf1;
  font-size: .8125rem;
  line-height: 1.55;
}

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
  .example pre, .example__header, .example__note { padding-inline: 12px; }
  .entry-card { padding: 12px; }
  .entry-grid { gap: 10px; }
  .featured { padding: 18px 16px; }
}
</style>
