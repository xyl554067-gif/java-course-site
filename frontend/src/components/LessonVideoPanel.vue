<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { LearningVideo } from '@/api'

const props = defineProps<{ videos: LearningVideo[]; selected: LearningVideo }>()
const emit = defineEmits<{ select: [id: number] }>()
const showPlayer = ref(false)

watch(() => props.selected.id, () => { showPlayer.value = false })

const locationParams = computed(() => ({
  p: String(props.selected.partNumber),
  ...(props.selected.startSeconds ? { t: String(props.selected.startSeconds) } : {}),
}))

const playerUrl = computed(() => {
  const params = new URLSearchParams({
    bvid: props.selected.bvid,
    ...locationParams.value,
    autoplay: '0',
    danmaku: '0',
  })
  return 'https://player.bilibili.com/player.html?' + params.toString()
})

const sourceUrl = computed(() => props.selected.sourceUrl + '?' + new URLSearchParams(locationParams.value))
</script>

<template>
  <section class="card lesson-video" aria-labelledby="lesson-video-title">
    <h2 id="lesson-video-title">配套视频</h2>
    <label v-if="videos.length > 1" class="video-choice">
      选择视频
      <select :value="selected.id" @change="emit('select', Number(($event.target as HTMLSelectElement).value))">
        <option v-for="video in videos" :key="video.id" :value="video.id">{{ video.label }}</option>
      </select>
    </label>
    <h3>{{ selected.label }}</h3>
    <p class="video-credit">{{ selected.uploader }} · B 站第 {{ selected.partNumber }} 集</p>
    <iframe
      v-if="showPlayer"
      :key="playerUrl"
      :src="playerUrl"
      :title="selected.label + ' · B 站播放器'"
      allow="fullscreen"
      referrerpolicy="strict-origin-when-cross-origin"
      allowfullscreen
    />
    <button v-else type="button" class="video-load" @click="showPlayer = true">
      <span aria-hidden="true">▶</span> 加载 B 站播放器
    </button>
    <p v-if="selected.recommendation" class="video-note">{{ selected.recommendation }}</p>
    <a :href="sourceUrl" target="_blank" rel="noopener noreferrer">去 B 站观看 ↗</a>
  </section>
</template>

<style scoped>
.lesson-video { padding: 20px; min-width: 0; }
.lesson-video h2 { margin: 0 0 10px; }
.lesson-video h3 { margin: 12px 0 0; }
.video-choice { display: grid; gap: 4px; }
.video-choice select { width: 100%; padding: 8px; border: 1px solid var(--c-line); border-radius: 8px; font: inherit; }
.video-credit, .video-note { color: var(--c-ink-soft); font-size: .9rem; }
.video-credit { margin: 4px 0 12px; }
iframe, .video-load { display: block; width: 100%; aspect-ratio: 16 / 9; border: 0; border-radius: 12px; }
.video-load { cursor: pointer; background: var(--c-cream-deep); color: var(--c-ink); font: inherit; }
.video-load span { margin-right: 5px; }
.lesson-video a { display: inline-block; margin-top: 8px; }
</style>
