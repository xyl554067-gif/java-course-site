<script setup lang="ts">
import { computed } from 'vue'
import type { Course, Lesson } from '@/api'
import { useProgressStore } from '@/stores/progress'

const props = defineProps<{ course: Course; lesson?: Lesson }>()
const progress = useProgressStore()
const titleParts = computed(() => props.course.title.split(/(?<=、)|(?=与)/))

const stages = [
  { time: '0–4', title: '数据封装', explanation: '运行账户示例，观察非法存款后余额不变。' },
  { time: '4–8', title: '访问控制', explanation: '看四种权限的对照表，判断两段代码能否编译。' },
  { time: '8–12', title: '包管理', explanation: '对照两个包里的源码，修复一次访问报错。' },
  { time: '12–15', title: '重构验收', explanation: '检查正常输入、非法输入和整数溢出。' },
]
</script>

<template>
  <header class="topic-hero card">
    <div class="topic-hero__intro">
      <RouterLink :to="{ name: 'course', params: { slug: 'java-mastery' } }" class="topic-hero__back">← Java 课程目录</RouterLink>
      <h1 class="title-round"><span v-for="part in titleParts" :key="part">{{ part }}</span></h1>
      <p class="topic-hero__desc">{{ course.description }}</p>
      <div v-if="lesson" class="topic-hero__actions">
        <RouterLink :to="{ name: 'lesson', params: { slug: lesson.slug } }" class="btn btn--primary">
          {{ progress.isCompleted(lesson.id) ? '复习这节课' : '进入知识点讲解' }} →
        </RouterLink>
        <span>1 节课 · {{ lesson.durationMin }} 分钟</span>
      </div>
    </div>

    <section class="topic-timeline" aria-labelledby="topic-timeline-title">
      <h2 id="topic-timeline-title" class="title-round">课堂路线</h2>
      <ol>
        <li v-for="stage in stages" :key="stage.time">
          <span class="topic-timeline__time">{{ stage.time }} 分钟</span>
          <div>
            <strong>{{ stage.title }}</strong>
            <p>{{ stage.explanation }}</p>
          </div>
        </li>
      </ol>
    </section>
  </header>
</template>

<style scoped>
.topic-hero {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr);
  gap: clamp(20px, 4vw, 48px);
  align-items: center;
  padding: clamp(22px, 4.1vw, 48px);
  background: radial-gradient(ellipse at 94% 16%, #ede7ff 0%, transparent 66%), var(--c-paper);
}
.topic-hero__back { display: inline-flex; margin-bottom: 18px; color: var(--c-ink-soft); font-size: .9rem; }
.topic-hero h1 { margin: 0 0 14px; font-size: clamp(1.85rem, 3.65vw, 3.05rem); line-height: 1.16; }
.topic-hero h1 span { display: inline-block; }
.topic-hero__desc { max-width: 29rem; margin: 0; color: var(--c-ink-soft); line-height: 1.75; }
.topic-hero__actions { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; margin-top: 22px; }
.topic-hero__actions span { color: var(--c-ink-soft); font-size: .92rem; }

.topic-timeline { min-width: 0; padding: clamp(14px, 2vw, 22px); border: 1px solid #cdc0e4; border-radius: var(--radius-md); background: var(--c-paper); }
.topic-timeline h2 { margin: 0 0 12px; font-size: 1.2rem; }
.topic-timeline ol { padding: 0; margin: 0; list-style: none; }
.topic-timeline li { display: grid; grid-template-columns: auto minmax(0, 1fr); align-items: baseline; gap: 12px; padding: 8px 0; }
.topic-timeline li + li { border-top: 1px solid #e7e0f2; }
.topic-timeline__time { min-width: 5.2em; font-size: .8rem; font-weight: 750; font-variant-numeric: tabular-nums; color: #514181; white-space: nowrap; }
.topic-timeline strong { font-size: .93rem; }
.topic-timeline p { margin: 3px 0 0; color: var(--c-ink-soft); font-size: .83rem; line-height: 1.5; }

@media (max-width: 760px) {
  .topic-hero { grid-template-columns: minmax(0, 1fr); }
  :global(body:has(.topic-hero) .pet-layer) { display: none; }
  :global(body:has(.topic-hero) .fab) { width: 44px; height: 44px; bottom: 12px; left: 12px; }
}
</style>
