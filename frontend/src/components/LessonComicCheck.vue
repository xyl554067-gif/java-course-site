<script setup lang="ts">
import { ref } from 'vue'
import type { SelfCheckResult } from '@/stores/progress'
import type { LessonComicPrompt } from '@/content/lesson-comic-prompts'

const props = defineProps<{ prompt: LessonComicPrompt; passed: boolean; reviewing: boolean }>()
const emit = defineEmits<{ result: [result: SelfCheckResult] }>()
const stickerBase = (import.meta.env.BASE_URL || '/') + 'assets/lesson-stickers/'
const selected = ref<number | null>(props.passed ? props.prompt.correct : null)
const feedback = ref<'hint' | 'correct' | null>(props.passed ? 'correct' : null)

function checkAnswer() {
  if (selected.value === null) return
  feedback.value = selected.value === props.prompt.correct ? 'correct' : 'hint'
  emit('result', feedback.value === 'correct' ? (props.reviewing ? 'REVIEWED' : 'PASSED') : 'WRONG')
}
</script>

<template>
  <section id="comic-check" class="comic-check" aria-labelledby="comic-check-title">
    <div class="section-head"><span class="dot" /><h2 id="comic-check-title">{{ reviewing ? "鲸鲸错题复习" : "鲸鲸漫画自测" }}</h2><span class="line" /></div>

    <div class="comic-check__scene">
      <img :src="stickerBase + 'code.webp'" alt="" width="72" height="90" loading="lazy" />
      <div>
        <p class="comic-check__scene-label">鲸鲸的现场</p>
        <ul class="comic-check__props" aria-label="场景线索" role="list">
          <li v-for="(item, index) in prompt.scene" :key="index">{{ item }}</li>
        </ul>
      </div>
    </div>

    <form @submit.prevent="checkAnswer">
      <fieldset :disabled="feedback === 'correct'">
        <legend>{{ prompt.question }}</legend>
        <label v-for="(option, index) in prompt.options" :key="option" class="comic-check__option">
          <input v-model="selected" type="radio" :value="index" name="comic-prediction" />
          <span>{{ option }}</span>
        </label>
        <button v-if="feedback !== 'correct'" type="submit" class="btn btn--sm btn--primary" :disabled="selected === null">检查预测</button>
      </fieldset>
    </form>

    <div aria-live="polite">
      <div v-if="feedback === 'hint'" class="comic-check__feedback">
        <img :src="stickerBase + 'flow.webp'" alt="" width="56" height="68" />
        <div><strong>鲸鲸提示</strong><p>{{ prompt.hint }} 再试一次。</p></div>
      </div>
      <p v-if="feedback === 'correct'" class="comic-check__correct">{{ reviewing ? "复习通过。看看漫画里的解释。" : "自测通过。看看漫画里的解释。" }}</p>
    </div>
    <slot v-if="feedback === 'correct'" name="explanation" />
  </section>
</template>

<style scoped>
.comic-check {
  margin-top: 30px;
  scroll-margin-top: calc(var(--nav-h) + 16px);
}
.comic-check__scene {
  display: grid;
  grid-template-columns: clamp(42px, 14%, 72px) minmax(0, 1fr);
  gap: clamp(8px, 2vw, 16px);
  align-items: center;
  padding: 10px 12px;
  border: 1px solid var(--c-line);
  border-radius: 12px;
  background: var(--c-cream);
}
.comic-check__scene img, .comic-check__feedback img {
  display: block;
  width: 100%;
  height: auto;
}
.comic-check__scene-label {
  margin: 0 0 6px;
  font-weight: 750;
}
.comic-check__props {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin: 0;
  padding: 0;
  list-style: none;
}
.comic-check__props li {
  max-width: 100%;
  padding: 3px 8px;
  border: 1px solid var(--c-line);
  border-radius: 8px;
  background: var(--c-paper);
  font-size: .85rem;
  overflow-wrap: anywhere;
}
.comic-check fieldset {
  min-width: 0;
  margin: 14px 0 0;
  padding: 0;
  border: 0;
}
.comic-check legend {
  font-weight: 700;
  overflow-wrap: anywhere;
}
.comic-check__option {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin: 8px 0;
}
.comic-check__option input { flex: none; }
.comic-check fieldset button { margin-top: 6px; }
.comic-check__feedback {
  display: grid;
  grid-template-columns: 56px minmax(0, 1fr);
  gap: 10px;
  align-items: center;
  margin-top: 12px;
  padding: 10px 12px;
  border-radius: 8px;
  background: var(--c-cream);
}
.comic-check__feedback p { margin: 2px 0 0; }
.comic-check__correct { margin: 12px 0; font-weight: 700; }
</style>
