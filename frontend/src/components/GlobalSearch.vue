<script setup lang="ts">
import { ref, watch, onUnmounted } from 'vue'
import { searchApi } from '@/api'

const props = defineProps<{ initial?: string }>()
const emit = defineEmits<{ (e: 'submit', kw: string): void }>()

const kw = ref(props.initial || '')
const suggest = ref<string[]>([])
const focused = ref(false)

let timer: number | undefined
let suggestionVersion = 0

function clearSuggestions() {
  suggestionVersion++
  window.clearTimeout(timer)
  suggest.value = []
}

async function loadSuggest() {
  const version = ++suggestionVersion
  const q = kw.value.trim()
  try {
    const results = await searchApi.suggest(q)
    if (version === suggestionVersion) suggest.value = results
  } catch {
    if (version === suggestionVersion) suggest.value = []
  }
}

function onInput() {
  clearSuggestions()
  if (kw.value.trim().length >= 2) timer = window.setTimeout(loadSuggest, 220)
}

function submit() {
  const q = kw.value.trim()
  if (!q) return
  clearSuggestions()
  focused.value = false
  emit('submit', q)
}

function pick(s: string) {
  kw.value = s
  submit()
}

watch(() => props.initial, (value) => {
  clearSuggestions()
  kw.value = value || ''
})

onUnmounted(clearSuggestions)
</script>

<template>
  <div class="gs">
    <input
      v-model="kw"
      type="search"
      aria-label="搜索课时、知识点和代码"
      class="input gs__input"
      placeholder="搜课时、知识点、代码片段…"
      @input="onInput"
      @focus="focused = true"
      @blur="() => { focused = false }"
      @keyup.enter="submit"
    />
    <button class="btn btn--sm btn--mint gs__btn" @click="submit">搜索</button>

    <ul v-if="focused && suggest.length" class="gs__list card">
      <li v-for="s in suggest" :key="s" @mousedown.prevent="pick(s)">{{ s }}</li>
    </ul>
  </div>
</template>

<style scoped>
.gs { position: relative; display: flex; min-width: 0; align-items: center; gap: 8px; }
.gs__input { width: 260px; min-width: 0; height: 42px; padding: 8px 16px; font-size: 14px; }
.gs__btn { flex: none; height: 42px; white-space: nowrap; }
.gs__list {
  position: absolute;
  top: 48px; left: 0;
  right: 60px;
  margin: 0; padding: 6px;
  list-style: none;
  z-index: 60;
  max-height: 300px;
  overflow-y: auto;
  box-shadow: var(--shadow-md);
}
.gs__list li {
  padding: 8px 12px;
  font-size: 14px;
  border-radius: var(--radius-sm);
  cursor: pointer;
}
.gs__list li:hover { background: var(--c-sun); }

@media (max-width: 900px) {
  .gs__input { width: 160px; }
}
</style>
