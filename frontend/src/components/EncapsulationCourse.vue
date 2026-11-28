<script setup lang="ts">
import { computed } from 'vue'
import type { Course, Lesson } from '@/api'
import { useProgressStore } from '@/stores/progress'

const props = defineProps<{ course: Course; lesson?: Lesson }>()
const progress = useProgressStore()
const titleParts = computed(() => props.course.title.split(/(?<=、)|(?=与)/))

const stages = [
  { title: '用封装保护余额', explanation: '禁止直接修改余额，通过受控方法校验存款。' },
  { title: '用包组织代码', explanation: '把账户和登记入口放到两个包，认识 package 与 import。' },
  { title: '判断访问权限', explanation: '用一张表理解四种修饰方式，判断两段代码能否编译。' },
  { title: '修复错误并验收', explanation: '修复跨包调用，核对成功、失败与边界输入。' },
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
      </div>
      <p v-if="lesson" class="topic-hero__credit">
        <RouterLink :to="{ name: 'lesson', params: { slug: lesson.slug }, hash: '#topic-knowledge' }">专题知识库</RouterLink>
        · 角色一整理知识条目、代码示例及检索验收题
      </p>
    </div>

    <section class="topic-outline" aria-labelledby="topic-outline-title">
      <h2 id="topic-outline-title" class="title-round">学习路线</h2>
      <ol>
        <li v-for="stage in stages" :key="stage.title">
          <strong>{{ stage.title }}</strong>
          <p>{{ stage.explanation }}</p>
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
.topic-hero__credit { margin: 12px 0 0; color: var(--c-ink-soft); font-size: .9rem; }

.topic-outline { min-width: 0; padding: clamp(14px, 2vw, 22px); border: 1px solid #cdc0e4; border-radius: var(--radius-md); background: var(--c-paper); }
.topic-outline h2 { margin: 0 0 12px; font-size: 1.2rem; }
.topic-outline ol { padding-inline-start: 1.5em; margin: 0; }
.topic-outline li { padding: 8px 0 8px 4px; }
.topic-outline li::marker { color: #514181; font-weight: 750; }
.topic-outline li + li { border-top: 1px solid #e7e0f2; }
.topic-outline strong { font-size: .93rem; }
.topic-outline p { margin: 3px 0 0; color: var(--c-ink-soft); font-size: .83rem; line-height: 1.5; }

@media (max-width: 760px) {
  .topic-hero { grid-template-columns: minmax(0, 1fr); }
  :global(body:has(.topic-hero) .fab) { width: 44px; height: 44px; bottom: 12px; left: 12px; }
}
</style>
