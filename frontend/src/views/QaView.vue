<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { courseApi } from '@/api'

const items = ref<any[]>([])
const loading = ref(true)
const filter = ref('ALL')
const revealed = ref<Record<number, boolean>>({})

const FILTERS = [
  { key: 'ALL', label: '全部' },
  { key: 'CHOICE', label: '选择题' },
  { key: 'JUDGE', label: '判断题' },
  { key: 'CODE', label: '代码题' },
]

const DIFF_BADGE: Record<string, string> = {
  EASY: 'badge--mint',
  MEDIUM: 'badge--sun',
  HARD: 'badge--coral',
}
const DIFF_LABEL: Record<string, string> = {
  EASY: '简单',
  MEDIUM: '中等',
  HARD: '较难',
}

const list = computed(() =>
  filter.value === 'ALL' ? items.value : items.value.filter((i) => i.qaType === filter.value),
)

async function load() {
  loading.value = true
  try {
    items.value = await courseApi.qa()
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="container qa">
    <header class="qa__head">
      <h1 class="title-round qa__title">随堂题库</h1>
      <p class="qa__sub">做一做，看看你真的掌握了吗～</p>
    </header>

    <div class="qa__filters">
      <button
        v-for="f in FILTERS"
        :key="f.key"
        class="btn btn--sm"
        :class="filter === f.key ? 'btn--primary' : 'btn--ghost'"
        @click="filter = f.key"
      >
        {{ f.label }}
      </button>
    </div>

    <div v-if="loading" class="qa__loading"><div class="spinner" /></div>

    <div v-else class="qa__list">
      <article v-for="(q, i) in list" :key="q.id" class="qitem card">
        <header class="qitem__head">
          <span class="qitem__no">{{ i + 1 }}</span>
          <span class="badge" :class="DIFF_BADGE[q.difficulty] || 'badge--sun'">
            {{ DIFF_LABEL[q.difficulty] || q.difficulty }}
          </span>
          <span class="badge badge--lilac">{{ q.qaType === 'CHOICE' ? '选择' : q.qaType === 'JUDGE' ? '判断' : '代码' }}</span>
        </header>

        <p class="qitem__text">{{ q.question }}</p>

        <button class="btn btn--sm btn--mint qitem__btn" @click="revealed[q.id] = !revealed[q.id]">
          {{ revealed[q.id] ? '收起答案' : '看答案' }}
        </button>

        <Transition name="expand">
          <div v-if="revealed[q.id]" class="qitem__answer">
            <p>{{ q.answer }}</p>
            <p v-if="q.answerKey" class="qitem__key">正确答案：{{ q.answerKey }}</p>
          </div>
        </Transition>
      </article>

      <div v-if="!list.length" class="empty">这个分类下暂时没有题目</div>
    </div>
  </div>
</template>

<style scoped>
.qa { padding-top: var(--space-lg); }
.qa__head { text-align: center; margin-bottom: 20px; }
.qa__title { margin: 0; font-size: 34px; }
.qa__sub { margin: 8px 0 0; color: var(--c-ink-faint); }

.qa__filters { display: flex; gap: 9px; justify-content: center; margin-bottom: 24px; }
.qa__loading { display: grid; place-items: center; padding: 60px 0; }
.qa__list { display: flex; flex-direction: column; gap: 15px; max-width: 780px; margin: 0 auto; }

.qitem { padding: 20px 24px; }
.qitem__head { display: flex; align-items: center; gap: 9px; margin-bottom: 12px; }
.qitem__no {
  display: grid; place-items: center;
  width: 30px; height: 30px;
  font-family: var(--font-round);
  font-weight: 700;
  background: var(--c-sun);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: 50%;
}
.qitem__text { margin: 0 0 14px; font-size: 15.5px; line-height: 1.85; font-weight: 700; }
.qitem__btn { margin-bottom: 4px; }
.qitem__answer {
  margin-top: 12px;
  padding: 14px 18px;
  background: var(--c-cream-deep);
  border-left: 6px solid var(--c-mint);
  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  animation: pop-in .28s both;
}
.qitem__answer p { margin: 0; font-size: 14px; line-height: 1.9; }
.qitem__key { margin-top: 8px !important; font-weight: 700; color: var(--c-coral-deep); }

.expand-enter-active, .expand-leave-active { transition: opacity .2s, max-height .24s; overflow: hidden; }
.expand-enter-from, .expand-leave-to { opacity: 0; max-height: 0; }
.expand-enter-to, .expand-leave-from { max-height: 500px; }
</style>