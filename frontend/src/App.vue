<script setup lang="ts">

// 静态资源基址：GitHub Pages 子路径部署时用 BASE_URL 拼接，避免绝对路径 404
const ASSET_BASE = import.meta.env.BASE_URL || '/'
import { onMounted, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAgentStore } from '@/stores/agent'
import { useProgressStore } from '@/stores/progress'
import AgentDrawer from '@/components/AgentDrawer.vue'
import FloatingPet from '@/components/FloatingPet.vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const agent = useAgentStore()
const progress = useProgressStore()

const bare = computed(() => route.meta.bare === true)

onMounted(async () => {
  await auth.bootstrap()
  // 助手资料只在有登录态时拉取：未登录时调用 API 会产生无意义的请求
  // （GitHub Pages 静态部署下 API 未就绪，表现为 404 噪音）
  if (auth.isLogged) {
    void agent.loadProfile()
    void progress.load()
  }
})

// 登录态建立后再拉进度与助手资料（首帧token 可能还没就绪）
watch(() => auth.isLogged, (v) => {
  if (v) {
    void progress.load()
    void agent.loadProfile()
  }
})

function onSearch(kw: string) {
  if (kw.trim()) router.push({ name: 'search', query: { q: kw.trim() } })
}

async function handleLogout() {
  await auth.logout()
  agent.reset()
  progress.reset()
  router.push({ name: 'login' })
}
</script>

<template>
  <div class="app-shell">
    <!-- 顶部导航 -->
    <header v-if="!bare" class="nav">
      <div class="container nav__inner">
        <RouterLink to="/" class="nav__brand">
          <img :src="ASSET_BASE + 'assets/agent/agent-idle.png'" alt="鲸鲸" class="nav__logo" />
          <span class="nav__title title-round">Java 精通之路</span>
        </RouterLink>

          <nav class="nav__links">
            <RouterLink to="/" class="nav__link">首页</RouterLink>
            <RouterLink to="/course/java-mastery" class="nav__link">课程目录</RouterLink>
            <RouterLink to="/exercises" class="nav__link">代码练习</RouterLink>
            <RouterLink to="/qa" class="nav__link">题库</RouterLink>
          </nav>

        <div class="nav__right">
          <GlobalSearch @submit="onSearch" />
          <button
            class="btn btn--sm btn--sun nav__agent"
            :aria-expanded="agent.panelOpen"
            aria-controls="agent-drawer"
            @click="agent.toggle()"
          >
            鲸鲸助教
          </button>
          <div class="nav__user">
            <span class="badge badge--lilac">{{ auth.displayName }}</span>
            <button class="btn btn--sm btn--ghost" @click="handleLogout">退出</button>
          </div>
        </div>
      </div>
    </header>

    <main class="app-main" :class="{ 'app-main--bare': bare }">
      <RouterView v-slot="{ Component }">
        <Transition name="fade" mode="out-in">
          <component :is="Component" />
        </Transition>
      </RouterView>
    </main>

    <!-- 鲸鲸助教抽屉 -->
    <AgentDrawer v-if="!bare" />

    <!-- 悬浮式 AI 助教桌宠（始终在最上层，可拖拽，点击唤出对话气泡） -->
    <FloatingPet v-if="!bare" />

    <!-- 快捷提问悬浮球（移动端也可见） -->
    <button
      v-if="!bare && !agent.panelOpen"
      class="fab"
      :aria-expanded="agent.panelOpen"
      aria-controls="agent-drawer"
      @click="agent.open()"
      title="叫醒鲸鲸"
    >
      <img :src="ASSET_BASE + 'assets/agent/agent-idle.png'" alt="鲸鲸" />
      <span class="fab__dot" />
    </button>
  </div>
</template>

<style scoped>
.app-shell { min-height: 100%; display: flex; flex-direction: column; }
.app-main { flex: 1; padding-bottom: var(--space-xl); }
.app-main--bare { padding-bottom: 0; }

.nav {
  position: sticky;
  top: 0;
  z-index: 40;
  background: var(--c-cream);
  border-bottom: var(--bw-base) solid var(--c-line);
  box-shadow: 0 4px 0 rgba(45, 53, 97, .12);
}
.nav__inner {
  height: var(--nav-h);
  display: flex;
  align-items: center;
  gap: var(--space-md);
}
.nav__brand { display: flex; align-items: center; gap: 10px; text-decoration: none; color: var(--c-ink); }
.nav__logo { width: 42px; height: 42px; image-rendering: auto; }
.nav__title { font-size: 21px; font-weight: 800; white-space: nowrap; }

.nav__links { display: flex; gap: 6px; }
.nav__link {
  padding: 6px 14px;
  font-family: var(--font-round);
  font-size: 15px;
  font-weight: 700;
  color: var(--c-ink-soft);
  text-decoration: none;
  border: var(--bw-thin) solid transparent;
  border-radius: var(--radius-full);
  transition: all .16s;
}
.nav__link:hover { background: var(--c-cream-deep); color: var(--c-ink); }
.nav__link.router-link-active {
  background: var(--c-mint);
  color: #fff;
  border-color: var(--c-line);
  box-shadow: var(--shadow-sm);
}

.nav__right { margin-left: auto; display: flex; align-items: center; gap: 10px; }
.nav__agent { white-space: nowrap; }
.nav__user { display: flex; align-items: center; gap: 8px; }

.fab {
  position: fixed;
  left: 26px;
  bottom: 26px;
  width: 72px; height: 72px;
  padding: 0;
  background: var(--c-paper);
  border: var(--bw-base) solid var(--c-line);
  border-radius: 50%;
  box-shadow: var(--shadow-md);
  cursor: pointer;
  animation: float-y 3.6s ease-in-out infinite;
  transition: transform .18s;
  z-index: 45;
}
.fab:hover { transform: scale(1.08) rotate(-4deg); }
.fab img { width: 100%; height: 100%; border-radius: 50%; }
.fab__dot {
  position: absolute;
  top: 4px; right: 6px;
  width: 14px; height: 14px;
  background: var(--c-coral);
  border: 2px solid var(--c-line);
  border-radius: 50%;
}

.fade-enter-active, .fade-leave-active { transition: opacity .18s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }

@media (max-width: 1000px) {
  .nav__links { display: none; }
  .nav__title { font-size: 17px; }
}
@media (max-width: 640px) {
  .nav__user .badge { display: none; }
  .nav__agent { display: none; }
}
</style>