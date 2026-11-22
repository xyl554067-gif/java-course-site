<script setup lang="ts">
import { computed, onUnmounted, ref, useId, watch } from 'vue'
import { searchApi } from '@/api'

const props = defineProps<{ initial?: string }>()
const emit = defineEmits<{ (e: 'submit', kw: string): void }>()

const kw = ref(props.initial || '')
const suggest = ref<string[]>([])
const focused = ref(false)
const activeIndex = ref(-1)
const suggestionListId = useId()
const showSuggestions = computed(() => focused.value && suggest.value.length > 0)
const optionId = (index: number) => `${suggestionListId}-${index}`

let timer: number | undefined
let suggestionVersion = 0

function clearSuggestions() {
  suggestionVersion++
  window.clearTimeout(timer)
  suggest.value = []
  activeIndex.value = -1
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

function onInput(event: Event) {
  if ((event as InputEvent).isComposing) return
  clearSuggestions()
  if (kw.value.trim().length >= 2) timer = window.setTimeout(loadSuggest, 220)
}

function submit() {
  const q = kw.value.trim()
  if (!q) return
  clearSuggestions()
  emit('submit', q)
}

function pick(s: string) {
  kw.value = s
  submit()
}

function onBlur() {
  focused.value = false
  activeIndex.value = -1
}

function onKeydown(event: KeyboardEvent) {
  if (event.isComposing || event.keyCode === 229) return
  if (event.key === 'Enter') {
    event.preventDefault()
    const selected = showSuggestions.value ? suggest.value[activeIndex.value] : undefined
    if (selected) pick(selected)
    else submit()
    return
  }
  if (!showSuggestions.value) return
  if (event.key === 'Escape') {
    event.preventDefault()
    clearSuggestions()
  } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
    event.preventDefault()
    const last = suggest.value.length - 1
    if (event.key === 'ArrowDown') activeIndex.value = Math.min(activeIndex.value + 1, last)
    else activeIndex.value = activeIndex.value < 0 ? last : Math.max(activeIndex.value - 1, 0)
    document.getElementById(optionId(activeIndex.value))?.scrollIntoView({ block: 'nearest', inline: 'nearest' })
  }
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
      role="combobox"
      aria-label="搜索课时、知识点和代码"
      aria-autocomplete="list"
      :aria-expanded="showSuggestions"
      :aria-controls="showSuggestions ? suggestionListId : undefined"
      :aria-activedescendant="showSuggestions && activeIndex >= 0 ? optionId(activeIndex) : undefined"
      class="input gs__input"
      placeholder="搜课时、知识点、代码片段…"
      @input="onInput"
      @focus="focused = true"
      @blur="onBlur"
      @keydown="onKeydown"
    />
    <button type="button" class="btn btn--sm btn--mint gs__btn" @click="submit">搜索</button>

    <ul v-if="showSuggestions" :id="suggestionListId" role="listbox" aria-label="搜索建议" class="gs__list card">
      <li
        v-for="(s, index) in suggest"
        :id="optionId(index)"
        :key="s"
        role="option"
        :aria-selected="index === activeIndex"
        @mousedown.prevent
        @click="pick(s)"
      >{{ s }}</li>
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
.gs__list li:hover,
.gs__list li[aria-selected="true"] { background: var(--c-sun); color: var(--c-ink); }

@media (max-width: 900px) {
  .gs__input { width: 160px; }
}
</style>
