<script setup lang="ts">
defineProps<{
  topics: Array<{ id: string; title: string; items: unknown[] }>
  selected: string
}>()
defineEmits<{ select: [id: string] }>()
</script>

<template>
  <section class="practice-topics" aria-labelledby="practice-topics-heading">
    <div class="practice-topics__heading">
      <h2 id="practice-topics-heading" class="title-round">按知识点练习</h2>
      <button v-if="selected" type="button" class="btn btn--sm btn--ghost" @click="$emit('select', '')">回到分区总览</button>
    </div>
    <ul class="practice-topics__grid">
      <li v-for="topic in topics" :key="topic.id">
        <button type="button" class="practice-topic" :aria-pressed="selected === topic.id" @click="$emit('select', topic.id)">
          <span>{{ topic.title }}</span>
          <small>{{ topic.items.length }} 道题</small>
        </button>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.practice-topics { margin-block: 20px; }
.practice-topics__heading { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 10px; margin-bottom: 12px; }
.practice-topics__heading h2 { margin: 0; font-size: 1.3rem; }
.practice-topics__grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; list-style: none; margin: 0; padding: 0; }
.practice-topic {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 8px;
  width: 100%; height: 100%; padding: 12px;
  border: 1px solid #c6b9df; border-radius: var(--radius-md);
  background: var(--c-paper); color: var(--c-ink); cursor: pointer; text-align: left; font: inherit;
}
.practice-topic span { font-weight: 750; overflow-wrap: anywhere; }
.practice-topic small { flex: none; color: #514181; white-space: nowrap; }
.practice-topic:hover, .practice-topic[aria-pressed="true"] { background: #eee8ff; border-color: #695693; }
.practice-topic[aria-pressed="true"] { box-shadow: inset 0 0 0 1px #695693; }
.practice-topic:focus-visible { outline: 2px solid #514181; outline-offset: 2px; }

@media (max-width: 960px) { .practice-topics__grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 760px) {
  :global(body:has(.qa, .ex) .pet-layer) { display: none; }
  :global(body:has(.qa, .ex) .fab) { width: 44px; height: 44px; bottom: 12px; left: 12px; }
}
@media (max-width: 430px) { .practice-topic { flex-direction: column; gap: 5px; padding: 10px; } }
</style>
