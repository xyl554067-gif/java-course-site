<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  slug: string
  title: string
  description: string
}>()

const imageUrl = computed(() =>
  (import.meta.env.BASE_URL || '/') + 'assets/lesson-comics/' + encodeURIComponent(props.slug) + '.webp'
)
</script>

<template>
  <figure class="lesson-comic">
    <figcaption class="lesson-comic__caption">
      <div>
        <span class="lesson-comic__label">鲸鲸小漫画</span>
        <span class="lesson-comic__title">{{ title }}</span>
      </div>
      <a :href="imageUrl" target="_blank" rel="noopener noreferrer">查看原图<span class="lesson-comic__sr">（新标签页）</span></a>
    </figcaption>

    <img
      :src="imageUrl"
      :alt="description"
      width="1280"
      height="820"
      loading="lazy"
      decoding="async"
    />
  </figure>
</template>

<style scoped>
.lesson-comic {
  margin: 0 0 24px;
  min-width: 0;
  overflow: hidden;
  border: 1px solid var(--c-line);
  border-radius: 16px;
  background: var(--c-paper);
  color: var(--c-ink);
}

.lesson-comic__caption {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: 6px 16px;
  padding: 10px 14px;
}

.lesson-comic__caption > div {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 4px 8px;
}

.lesson-comic__label {
  font-size: .78rem;
  font-weight: 700;
  color: var(--c-ink-soft);
}

.lesson-comic__title {
  font-weight: 700;
}

.lesson-comic__caption a {
  font-size: .85rem;
  text-decoration: underline;
  text-underline-offset: .2em;
}

.lesson-comic img {
  display: block;
  width: 100%;
  height: auto;
}

.lesson-comic__sr {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip-path: inset(50%);
  white-space: nowrap;
}
</style>
