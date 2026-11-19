<script setup lang="ts">
import { computed } from 'vue'
import type { Course, Lesson } from '@/api'
import { useProgressStore } from '@/stores/progress'
import { packageStarterZip } from '@/content/practice-catalog'

const props = defineProps<{ course: Course; lessons: Lesson[]; videoLessonIds: number[] }>()
const progress = useProgressStore()

const practice: Record<string, string> = {
  'encapsulation-account': '验证余额只在存款成功后更新',
  'encapsulation-access': '判断四段代码能否通过编译',
  'encapsulation-packages': '用 javac 复现并修复一次跨包错误',
  'encapsulation-refactor': '提交重构，核对 5 个测试结果',
}

const minutes = computed(() => props.lessons.reduce((sum, lesson) => sum + (lesson.durationMin ?? 0), 0))
const titleParts = computed(() => props.course.title.split(/(?<=、)|(?=与)/))
const completed = computed(() => props.lessons.filter(lesson => progress.isCompleted(lesson.id)).length)
const nextLesson = computed(() => props.lessons.find(lesson => !progress.isCompleted(lesson.id)) ?? props.lessons[0])
</script>

<template>
  <header class="topic-hero card">
    <div class="topic-hero__intro">
      <RouterLink :to="{ name: 'course', params: { slug: 'java-mastery' } }" class="topic-hero__back">← Java 课程目录</RouterLink>
      <h1 class="title-round"><span v-for="part in titleParts" :key="part">{{ part }}</span></h1>
      <p class="topic-hero__sub">{{ course.subtitle }}</p>
      <p class="topic-hero__desc">{{ course.description }}</p>
      <div class="topic-hero__actions">
        <RouterLink v-if="nextLesson" :to="{ name: 'lesson', params: { slug: nextLesson.slug } }" class="btn btn--primary">
          {{ completed === lessons.length ? '复习课程' : completed ? '继续学习' : '开始第一节' }} →
        </RouterLink>
        <span>{{ lessons.length }} 课时 · 约 {{ minutes }} 分钟</span>
      </div>
    </div>

    <div class="account-file">
      <div class="account-file__file"><span /> Account.java</div>
      <pre><code><span class="account-file__keyword">package</span> demo.bank;

<span class="account-file__keyword">public class</span> Account {
  <span class="account-file__keyword">private int</span> balance;

  <span class="account-file__keyword">public int</span> getBalance() {
    <span class="account-file__keyword">return</span> balance;
  }
}</code></pre>
      <dl>
        <div><dt>package</dt><dd>划分代码归属</dd></div>
        <div><dt>private</dt><dd>保护账户状态</dd></div>
        <div><dt>public</dt><dd>开放受控接口</dd></div>
      </dl>
    </div>
  </header>

  <section class="topic-plan" aria-labelledby="topic-plan-heading">
    <header class="topic-plan__head">
      <h2 id="topic-plan-heading" class="title-round">学习路线</h2>
      <span v-if="completed" class="topic-plan__count">已完成 {{ completed }} / {{ lessons.length }} 节</span>
    </header>
    <ol class="topic-plan__grid">
      <li v-for="(lesson, index) in lessons" :key="lesson.id" class="topic-card card">
        <header class="topic-card__head">
          <span class="topic-card__step">第 {{ index + 1 }} 节</span>
          <span v-if="progress.isCompleted(lesson.id)" class="topic-card__done">✓ 已完成</span>
          <span v-else>{{ lesson.durationMin }} 分钟</span>
        </header>
        <h3 class="title-round">
          <RouterLink :to="{ name: 'lesson', params: { slug: lesson.slug } }">{{ lesson.title }}</RouterLink>
        </h3>
        <p>{{ lesson.summary }}</p>
        <p v-if="practice[lesson.slug]" class="topic-card__practice"><span>动手</span>{{ practice[lesson.slug] }}</p>
        <footer class="topic-card__links">
          <RouterLink :to="{ name: 'lesson', params: { slug: lesson.slug } }">阅读课时 →</RouterLink>
          <RouterLink v-if="videoLessonIds.includes(lesson.id)" :to="{ name: 'lesson-lab', params: { slug: lesson.slug } }">边看边练</RouterLink>
          <RouterLink v-else-if="lesson.slug === 'encapsulation-access'" :to="{ name: 'lesson', params: { slug: lesson.slug }, hash: '#access-check' }">开始判断</RouterLink>
          <RouterLink v-else-if="lesson.slug === 'encapsulation-packages'" :to="{ name: 'lesson-lab', params: { slug: lesson.slug } }">打开实验室</RouterLink>
          <RouterLink v-else-if="lesson.slug === 'encapsulation-refactor'" :to="{ name: 'lesson', params: { slug: lesson.slug }, query: { tab: 'exercises' } }">开始重构</RouterLink>
          <a v-if="lesson.slug === 'encapsulation-packages'" :href="packageStarterZip" download>下载双包实验工程</a>
        </footer>
      </li>
    </ol>
  </section>
</template>

<style scoped>
.topic-hero {
  display: grid;
  grid-template-columns: minmax(0, 1.3fr) minmax(0, .9fr);
  gap: clamp(20px, 4vw, 56px);
  align-items: center;
  padding: clamp(20px, 4.6vw, 56px);
  background: radial-gradient(ellipse at 92% 18%, #ede7ff 0%, transparent 64%), var(--c-paper);
}
.topic-hero__back { display: inline-flex; margin-bottom: 20px; color: var(--c-ink-soft); font-size: .9rem; }
.topic-hero h1 { margin: 0 0 14px; font-size: clamp(1.85rem, 3.7vw, 3.125rem); line-height: 1.16; }
.topic-hero h1 span { display: inline-block; }
.topic-hero__sub { margin: 0 0 10px; color: var(--c-ink); font-size: clamp(1.05rem, 2vw, 1.27rem); font-weight: 750; }
.topic-hero__desc { max-width: 31rem; margin: 0; color: var(--c-ink-soft); line-height: 1.75; }
.topic-hero__actions { display: flex; flex-wrap: wrap; align-items: center; gap: 14px; margin-top: 22px; }
.topic-hero__actions span { color: var(--c-ink-soft); font-size: .92rem; }

.account-file { overflow: hidden; border: 1px solid #393865; border-radius: var(--radius-md); background: #242443; color: #f3f0ff; }
.account-file__file { display: flex; align-items: center; gap: 9px; padding: 11px 16px; border-bottom: 1px solid #514e76; color: #e4dbff; font: 500 .79rem/1.4 var(--font-mono); }
.account-file__file span { width: 8px; height: 8px; border-radius: 50%; background: #b6f5dd; }
.account-file pre { margin: 0; padding: 16px; overflow-x: auto; font: .8rem/1.55 var(--font-mono); }
.account-file__keyword { color: #cbb8ff; }
.account-file dl { display: flex; flex-wrap: wrap; gap: 10px 21px; margin: 0; padding: 12px 16px; border-top: 1px solid #514e76; background: #302e53; }
.account-file dt { color: #b6f5dd; font: 600 .78rem/1.5 var(--font-mono); }
.account-file dd { margin: 1px 0 0; font-size: .77rem; white-space: nowrap; }

.topic-plan { margin-block: 30px 42px; }
.topic-plan__head { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 10px; margin-bottom: 16px; }
.topic-plan__head h2 { margin: 0; font-size: clamp(1.35rem, 2.75vw, 1.85rem); }
.topic-plan__count, .topic-card__done { color: #225d4c; font-weight: 700; }
.topic-plan__grid { list-style: none; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; margin: 0; padding: 0; }
.topic-card { display: flex; flex-direction: column; gap: 10px; min-width: 0; padding: clamp(15px, 2.4vw, 24px); }
.topic-card__head { display: flex; align-items: center; justify-content: space-between; gap: 8px; color: var(--c-ink-soft); font-size: .84rem; }
.topic-card__step { padding: 4px 10px; border-radius: 999px; background: #e7e2ff; color: #443771; font-weight: 750; }
.topic-card:nth-child(even) .topic-card__step { background: #dff5ed; color: #215e51; }
.topic-card h3 { margin: 0; font-size: clamp(1.1rem, 2vw, 1.34rem); }
.topic-card h3 a { color: var(--c-ink); text-decoration: none; }
.topic-card h3 a:hover { text-decoration: underline; }
.topic-card p { margin: 0; color: var(--c-ink-soft); line-height: 1.6; }
.topic-card .topic-card__practice { display: flex; align-items: baseline; gap: 8px; padding-top: 4px; color: var(--c-ink); font-size: .89rem; }
.topic-card__practice span { flex: none; color: #514181; font-weight: 750; }
.topic-card__links { display: flex; flex-wrap: wrap; gap: 8px 18px; margin-top: auto; padding-top: 10px; }
.topic-card__links a { color: #514181; font-size: .88rem; font-weight: 750; }

@media (max-width: 760px) {
  .topic-hero, .topic-plan__grid { grid-template-columns: minmax(0, 1fr); }
  .topic-plan { margin-top: 24px; }
  :global(body:has(.topic-hero) .pet-layer) { display: none; }
  :global(body:has(.topic-hero) .fab) { width: 44px; height: 44px; bottom: 12px; left: 12px; }
}
</style>
