<script setup lang="ts">

// 静态资源基址：GitHub Pages 子路径部署时用 BASE_URL 拼接，避免绝对路径 404
const ASSET_BASE = import.meta.env.BASE_URL || '/'
import { ref, watch, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import GlobalSearch from '@/components/GlobalSearch.vue'
import { searchApi, type SearchHit } from '@/api'
import { errMsg } from '@/api/http'

const route = useRoute()
const router = useRouter()
const q = ref('')
const hits = ref<SearchHit[]>([])
const loading = ref(false)
const searched = ref(false)
const error = ref('')
let searchVersion = 0

async function doSearch(keyword: string) {
  const version = ++searchVersion
  const key = keyword.trim()
  q.value = key
  hits.value = []
  error.value = ''
  searched.value = false
  loading.value = Boolean(key)
  if (!key) return
  try {
    const results = await searchApi.search(key)
    if (version !== searchVersion) return
    hits.value = results
    searched.value = true
  } catch (e) {
    if (version === searchVersion) error.value = errMsg(e)
  } finally {
    if (version === searchVersion) loading.value = false
  }
}

function submitSearch(keyword: string) {
  const key = keyword.trim()
  if (!key) return
  if (key === route.query.q) {
    void doSearch(key)
  } else {
    void router.push({ name: 'search', query: { ...route.query, q: key } })
  }
}

const TYPE_LABEL: Record<string, string> = {
  LESSON: '课时',
  MODULE: '模块',
  KNOWLEDGE: '知识点',
  CODE: '代码',
  QA: '题目',
}
const TYPE_BADGE: Record<string, string> = {
  LESSON: 'badge--mint',
  MODULE: 'badge--lilac',
  KNOWLEDGE: 'badge--sun',
  CODE: 'badge--coral',
  QA: 'badge--sky',
}

watch(
  () => route.query.q,
  (v) => {
    void doSearch(typeof v === 'string' ? v : '')
  },
  { immediate: true },
)

onUnmounted(() => { searchVersion++ })
</script>

<template>
  <div class="container search">
    <header class="search__head">
      <h1 class="title-round search__title">搜索结果</h1>
      <GlobalSearch :initial="q" @submit="submitSearch" />
    </header>

    <div v-if="loading" class="search__loading" role="status" aria-label="正在搜索"><div class="spinner" /></div>
    <div v-else-if="error" class="card search__error" role="alert">
      <p>{{ error }}</p>
      <button type="button" class="btn btn--primary" @click="doSearch(q)">重试搜索</button>
    </div>

    <template v-else-if="searched">
      <p class="search__count" role="status">
        找到 <strong>{{ hits.length }}</strong> 条与「<em>{{ q }}</em>」相关的内容
      </p>

      <div v-if="!hits.length" class="card search__empty">
        <img :src="ASSET_BASE + 'assets/agent/meme-oh.png'" alt="鲸鲸" class="search__empty-img" />
        <p>没有找到相关内容喵～ 换个关键词试试？</p>
        <ul class="search__tips">
          <li>试试「线程池」「JVM」「int」「多态」</li>
          <li>或者直接问右下角的鲸鲸助教</li>
        </ul>
      </div>

      <ul class="search__list">
        <li v-for="(h, i) in hits" :key="h.id" class="hit card card--hover" :style="{ animationDelay: `${Math.min(i, 12) * 40}ms` }">
          <div class="hit__head">
            <span class="badge" :class="TYPE_BADGE[h.targetType] || 'badge--sun'">
              {{ TYPE_LABEL[h.targetType] || h.targetType }}
            </span>
            <RouterLink :to="h.refUrl" class="hit__title">{{ h.title }}</RouterLink>
            <span class="hit__score">得分 {{ h.score }}</span>
          </div>
          <!-- 后端返回的摘要里带 <mark> 高亮 -->
          <p class="hit__snippet" v-html="h.highlight" />
        </li>
      </ul>
    </template>
    <p v-else>输入关键词，查找课时、知识点和代码示例。</p>
  </div>
</template>

<style scoped>
.search { padding-top: var(--space-lg); }
.search__head {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  flex-wrap: wrap;
  margin-bottom: var(--space-md);
}
.search__title { margin: 0; font-size: 28px; }
.search__head :deep(.gs) { flex: 1; min-width: 280px; }
.search__head :deep(.gs__input) { width: 100%; }

.search__loading { display: grid; place-items: center; padding: 60px 0; }
.search__error { padding: 24px; }
.search__error p { margin: 0 0 16px; }
.search__count { margin: 0 0 18px; font-size: 14px; color: var(--c-ink-soft); }
.search__count strong { color: var(--c-coral-deep); font-size: 17px; }
.search__count em { font-style: normal; font-weight: 700; color: var(--c-ink); }

.search__list { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 13px; }
.hit { padding: 17px 20px; animation: pop-in .35s both; }
.hit__head { display: flex; align-items: center; gap: 10px; margin-bottom: 8px; flex-wrap: wrap; }
.hit__title {
  font-family: var(--font-round);
  font-size: 17px;
  font-weight: 700;
  color: var(--c-ink);
  text-decoration: none;
}
.hit__title:hover { color: var(--c-coral-deep); }
.hit__score { margin-left: auto; font-size: 12px; color: var(--c-ink-faint); }
.hit__snippet {
  margin: 0;
  font-size: 13.5px;
  line-height: 1.9;
  color: var(--c-ink-soft);
}
.hit__snippet :deep(mark) {
  padding: 1px 4px;
  background: var(--c-sun);
  border-radius: 4px;
  font-weight: 700;
  color: var(--c-ink);
}

.search__empty { padding: 44px; text-align: center; }
.search__empty-img { width: 130px; height: 130px; }
.search__empty p { margin: 10px 0 14px; font-family: var(--font-round); font-weight: 700; }
.search__tips { margin: 0; padding: 0; list-style: none; font-size: 13px; color: var(--c-ink-faint); line-height: 2; }
</style>
