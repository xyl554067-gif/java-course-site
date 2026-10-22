import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import http, { request } from '@/api/http'

export interface ProgressSummary {
  totalLessons: number
  completed: number
  inProgress: number
  started: number
  totalSeconds: number
  studyCount: number
  favoriteCount: number
  overallPct: number
}

export interface ProgressItem {
  lessonId: number
  slug: string
  title: string
  moduleTitle: string
  progressPct: number
  completed: boolean
  lastSeconds: number
  totalSeconds: number
  studyCount: number
  updatedAt: string
}

export interface FavoriteItem {
  lessonId: number
  title: string
  slug: string
  summary: string
  moduleTitle: string
}

const emptySummary: ProgressSummary = {
  totalLessons: 42,
  completed: 0,
  inProgress: 0,
  started: 0,
  totalSeconds: 0,
  studyCount: 0,
  favoriteCount: 0,
  overallPct: 0,
}

export const useProgressStore = defineStore('progress', () => {
  const summary = ref<ProgressSummary>({ ...emptySummary })
  const items = ref<ProgressItem[]>([])
  const favorites = ref<FavoriteItem[]>([])
  /** lessonId -> 是否收藏 / 是否完成，课程目录打标用 */
  const favoriteIds = ref<Set<number>>(new Set())
  const completedIds = ref<Set<number>>(new Set())
  const loaded = ref(false)

  /** 单课时本地进度缓存，key 为 lessonId */
  const lessonProgress = ref<Record<number, ProgressItem | null>>({})

  const learningMinutes = computed(() => Math.round(summary.value.totalSeconds / 60))
  const hasProgress = computed(() => summary.value.started > 0)

  function mergeIds() {
    favoriteIds.value = new Set(favorites.value.map((f) => f.lessonId))
    completedIds.value = new Set(items.value.filter((i) => i.completed).map((i) => i.lessonId))
  }

  async function load() {
    const r = await request<{
      summary: ProgressSummary
      items: ProgressItem[]
      favorites: FavoriteItem[]
    }>(http.get('/progress'))
    summary.value = { ...emptySummary, ...r.summary }
    items.value = r.items || []
    favorites.value = r.favorites || []
    mergeIds()
    loaded.value = true
  }

  async function loadMarks() {
    const r = await request<{ favorites: number[]; completed: number[] }>(http.get('/progress/marks'))
    favoriteIds.value = new Set(r.favorites || [])
    completedIds.value = new Set(r.completed || [])
  }

  async function loadOne(lessonId: number) {
    try {
      const r = await request<{ progress: ProgressItem | null; favorite: boolean }>(
        http.get(`/progress/lesson/${lessonId}`),
      )
      lessonProgress.value[lessonId] = r.progress
      if (r.favorite) favoriteIds.value.add(lessonId)
      else favoriteIds.value.delete(lessonId)
      return r
    } catch {
      return null
    }
  }

  /**
   * 保存进度（节流调用）
   *
   * @param lastSeconds 本次会话累计已学秒数（覆盖写）
   * @param deltaSeconds 相对上次上报新增加的秒数（累加进总时长）
   * @param sessionKey 会话标识：同一会话重复上报只计一次学习次数
   */
  async function save(
    lessonId: number,
    pct: number,
    lastSeconds: number,
    deltaSeconds = 0,
    sessionKey = '',
  ) {
    const r = await request<{ progress: ProgressItem | null; favorite: boolean }>(
      http.put(`/progress/lesson/${lessonId}`, {
        progressPct: pct,
        lastSeconds,
        deltaSeconds,
        sessionKey,
      }),
    )
    lessonProgress.value[lessonId] = r.progress
    if (r.progress) {
      const idx = items.value.findIndex((i) => i.lessonId === lessonId)
      if (idx >= 0) items.value[idx] = r.progress
      else items.value.unshift(r.progress)
      if (r.progress.completed) completedIds.value.add(lessonId)
      else completedIds.value.delete(lessonId)
    }
    await refreshSummary()
    return r
  }

  async function markCompleted(lessonId: number, completed: boolean) {
    const r = await request<{ progress: ProgressItem | null }>(
      http.post(`/progress/lesson/${lessonId}/complete?completed=${completed}`),
    )
    if (r.progress) {
      const idx = items.value.findIndex((i) => i.lessonId === lessonId)
      if (idx >= 0) items.value[idx] = r.progress
      if (completed) completedIds.value.add(lessonId)
      else completedIds.value.delete(lessonId)
    }
    await refreshSummary()
    return r
  }

  async function toggleFavorite(lessonId: number) {
    const r = await request<{ favorite: boolean; summary: ProgressSummary }>(
      http.post(`/progress/lesson/${lessonId}/favorite`),
    )
    if (r.favorite) favoriteIds.value.add(lessonId)
    else favoriteIds.value.delete(lessonId)
    summary.value = { ...emptySummary, ...r.summary }
    return r.favorite
  }

  async function refreshSummary() {
    summary.value = await request<ProgressSummary>(http.get('/progress/summary'))
  }

  function isFavorite(lessonId: number) {
    return favoriteIds.value.has(lessonId)
  }

  function isCompleted(lessonId: number) {
    return completedIds.value.has(lessonId)
  }

  function progressOf(lessonId: number) {
    return lessonProgress.value[lessonId] || items.value.find((i) => i.lessonId === lessonId) || null
  }

  function reset() {
    summary.value = { ...emptySummary }
    items.value = []
    favorites.value = []
    favoriteIds.value = new Set()
    completedIds.value = new Set()
    lessonProgress.value = {}
    loaded.value = false
  }

  return {
    summary, items, favorites, favoriteIds, completedIds, loaded,
    lessonProgress, learningMinutes, hasProgress,
    load, loadMarks, loadOne, save, markCompleted, toggleFavorite, refreshSummary,
    isFavorite, isCompleted, progressOf, reset,
  }
})