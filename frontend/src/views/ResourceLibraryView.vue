<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute } from 'vue-router'
import {
  courseResources, resourceEntries, resourceExerciseSlug, resourceNoteById,
  resourceNotes, resourceTopicLabel, resourceTopics, type ResourceTopic,
} from '@/content/course-resources'

const route = useRoute()
const query = ref('')
const topic = ref<ResourceTopic | ''>('')
const noteId = computed(() => typeof route.params.note === 'string' ? route.params.note : '')
const activeNote = computed(() => resourceNoteById(noteId.value))
const terms = computed(() => query.value.trim().toLowerCase().split(/\s+/).filter(Boolean))

function matchesTerms(values: string[]) {
  const searchableText = values.join(' ').toLowerCase()
  return terms.value.every((term) => searchableText.includes(term))
}

const shownNotes = computed(() => resourceNotes.filter((note) =>
  (!topic.value || note.topic === topic.value)
    && matchesTerms([note.title, note.lessonTitle, note.summary,
      ...note.sources.map((id) => courseResources[id].title)]),
))

const shownSources = computed(() => resourceEntries.filter(([, source]) =>
  (!topic.value || source.topics.some((id) => id === topic.value))
    && matchesTerms([source.title, source.publisher, source.kind, source.description]),
))
</script>

<template>
  <div class="container resource-library">
    <template v-if="activeNote">
      <RouterLink class="resource-back" to="/resources">← 返回资料库</RouterLink>
      <article class="card resource-note" :key="activeNote.id">
        <header class="resource-heading">
          <span class="resource-topic">{{ resourceTopicLabel(activeNote.topic) }}</span>
          <h1>{{ activeNote.title }}</h1>
          <p>{{ activeNote.summary }}</p>
          <RouterLink class="btn btn--sm btn--ghost" :to="{ name: 'lesson', params: { slug: activeNote.lessonSlug } }">
            对应课时 · {{ activeNote.lessonTitle }}
          </RouterLink>
        </header>

        <section class="resource-section">
          <h2>原理</h2>
          <p v-for="paragraph in activeNote.explanation" :key="paragraph">{{ paragraph }}</p>
        </section>
        <section class="resource-section">
          <h2>动手验证</h2>
          <p>{{ activeNote.example.setup }}</p>
          <pre tabindex="0" aria-label="示例代码"><code>{{ activeNote.example.code }}</code></pre>
          <p><strong>预期结果</strong> {{ activeNote.example.result }}</p>
        </section>
        <section class="resource-section">
          <h2>自测</h2>
          <p>{{ activeNote.exercise.question }}</p>
          <details>
            <summary>查看参考答案</summary>
            <p>{{ activeNote.exercise.answer }}</p>
          </details>
          <div class="resource-practice">
            <RouterLink class="btn btn--sm btn--ghost" :to="{ name: 'qa', query: { resource: activeNote.id } }">
              做专题题目
            </RouterLink>
            <RouterLink class="btn btn--sm btn--mint" :to="{ name: 'exercise', params: { slug: resourceExerciseSlug(activeNote.id) } }">
              做配套代码练习
            </RouterLink>
          </div>
        </section>
        <section class="resource-section">
          <h2>参考资料</h2>
          <ul class="source-list">
            <li v-for="id in activeNote.sources" :key="id">
              <a :href="courseResources[id].url" target="_blank" rel="noopener noreferrer">{{ courseResources[id].title }} <span aria-hidden="true">↗</span></a>
              <p>{{ courseResources[id].description }}</p>
            </li>
          </ul>
        </section>
      </article>
    </template>

    <section v-else-if="noteId" class="card resource-note">
      <h1>未找到这篇补充讲解</h1>
      <RouterLink class="resource-back" to="/resources">← 返回资料库</RouterLink>
    </section>

    <template v-else>
      <header class="card library-heading">
        <h1>Java 课程资料库</h1>
        <p>按主题查找课时补充讲解、官方文档、教材和练习。</p>
        <div class="resource-filters">
          <label>
            <span>搜索资料</span>
            <input v-model="query" type="search" placeholder="例如 数组、Stream、JDBC" />
          </label>
          <label>
            <span>主题</span>
            <select v-model="topic">
              <option value="">全部主题</option>
              <option v-for="item in resourceTopics" :key="item.id" :value="item.id">{{ item.label }}</option>
            </select>
          </label>
        </div>
        <p class="resource-count" role="status">{{ shownNotes.length }} 篇补充讲解 · {{ shownSources.length }} 项资料</p>
      </header>

      <p v-if="!shownNotes.length && !shownSources.length" class="card empty-resources">
        没有匹配的讲解或资料。可以更换关键词或主题。
      </p>

      <section v-if="shownNotes.length" class="resource-group" aria-labelledby="resource-notes-title">
        <h2 id="resource-notes-title">补充讲解</h2>
        <ul class="resource-grid">
          <li v-for="note in shownNotes" :key="note.id" class="card resource-card">
            <span class="resource-topic">{{ resourceTopicLabel(note.topic) }}</span>
            <h3><RouterLink :to="{ name: 'resources', params: { note: note.id } }">{{ note.title }}</RouterLink></h3>
            <p>{{ note.summary }}</p>
          </li>
        </ul>
      </section>

      <section v-if="shownSources.length" class="resource-group" aria-labelledby="resource-sources-title">
        <h2 id="resource-sources-title">资料索引</h2>
        <ul class="resource-grid">
          <li v-for="[id, source] in shownSources" :key="id" class="card resource-card">
            <span class="resource-topic">{{ source.kind }} · {{ source.publisher }}</span>
            <h3><a :href="source.url" target="_blank" rel="noopener noreferrer">{{ source.title }} <span aria-hidden="true">↗</span></a></h3>
            <p>{{ source.description }}</p>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>

<style scoped>
.resource-library { max-width: 1120px; padding-block: clamp(24px, 5vw, 56px); }
.library-heading, .resource-note { padding: clamp(20px, 4vw, 38px); }
.library-heading { background: var(--c-cream); }
.library-heading h1, .resource-note h1 { margin: 0 0 8px; font-size: clamp(1.6rem, 4vw, 2.4rem); line-height: 1.25; }
.library-heading p, .resource-note p, .resource-card p { color: var(--c-ink-soft); line-height: 1.7; }
.resource-filters { display: grid; grid-template-columns: minmax(0, 1fr) minmax(10rem, 15rem); gap: 14px; margin-top: 20px; }
.resource-filters label { display: grid; gap: 5px; font-weight: 700; }
.resource-filters input, .resource-filters select {
  width: 100%;
  min-height: 44px;
  padding: 7px 12px;
  background: var(--c-paper);
  color: var(--c-ink);
  border: 2px solid var(--c-line);
  border-radius: 10px;
  font: inherit;
}
.resource-filters :focus-visible, .resource-library a:focus-visible, .resource-library summary:focus-visible {
  outline: 2px solid var(--c-line);
  outline-offset: 3px;
}
.resource-count { margin: 12px 0 0; font-size: .875rem; }
.resource-group { margin-top: 32px; }
.resource-group h2, .resource-section h2 { margin: 0 0 12px; font-size: 1.25rem; }
.resource-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 245px), 1fr)); gap: 14px; margin: 0; padding: 0; list-style: none; }
.resource-card { padding: 18px; min-width: 0; }
.resource-topic { display: block; margin-bottom: 6px; color: var(--c-ink-soft); font-size: .8125rem; font-weight: 700; }
.resource-card h3 { margin: 0; font-size: 1rem; line-height: 1.5; overflow-wrap: anywhere; }
.resource-card p, .source-list p { margin: 5px 0 0; font-size: .875rem; }
.resource-card a, .source-list a, .resource-back { color: var(--c-ink); text-decoration: underline; text-underline-offset: 3px; }
.resource-back { display: inline-block; margin-bottom: 14px; font-weight: 700; }
.resource-note { max-width: 820px; }
.resource-heading .btn { margin-top: 10px; }
.resource-section { border-top: 1px solid var(--c-line); padding-top: 22px; margin-top: 22px; }
.resource-section p + p { margin-top: 8px; }
.resource-section pre { overflow: auto; padding: 14px; margin: 12px 0; border: 1px solid var(--c-line); background: var(--c-cream); border-radius: 10px; }
.resource-section details { padding: 12px 14px; margin-top: 10px; background: var(--c-cream); border-radius: 10px; }
.resource-section details p { margin-top: 8px; }
.resource-section summary { cursor: pointer; font-weight: 700; }
.resource-practice { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 14px; }
.source-list { padding-inline-start: 20px; margin: 0; }
.source-list li + li { margin-top: 12px; }
.empty-resources { margin-top: 20px; padding: 18px; }
@media (max-width: 540px) {
  .resource-filters { grid-template-columns: 1fr; }
}
</style>
