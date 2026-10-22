<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { courseApi, type Course, type CourseModule } from '@/api'
import { useAgentStore } from '@/stores/agent'
import { useProgressStore } from '@/stores/progress'

const course = ref<Course | null>(null)
const modules = ref<CourseModule[]>([])
const loading = ref(true)
const openModules = ref<Record<number, boolean>>({})
const agent = useAgentStore()
const progress = useProgressStore()

const overallPct = computed(() => progress.summary.overallPct)

/** 模块图标：数据库里存的是英文 key，这里映射成 emoji，卡通感更强 */
const ICONS: Record<string, string> = {
  coffee: '☕',
  puzzle: '🧩',
  boxes: '🗃️',
  compass: '🧭',
  rocket: '🚀',
  code: '💻',
}

async function load() {
  loading.value = true
  try {
    // 一次取全：课程详情接口已内嵌模块→课时树，避免二次请求
    const detail = await courseApi.detail('java-mastery')
    course.value = (detail.course || detail) as Course
    modules.value = detail.modules || []
    // 默认展开第一个模块
    if (modules.value[0]) openModules.value[modules.value[0].id] = true
    void progress.load()
  } finally {
    loading.value = false
  }
}

function toggle(id: number) {
  openModules.value[id] = !openModules.value[id]
}

function askAbout(m: CourseModule) {
  agent.open()
  void agent.ask(`「${m.title}」这个模块主要讲什么？重点难点在哪？`).then(() => {})
}

onMounted(load)
</script>

<template>
  <div class="container home">
    <!-- Hero -->
    <section v-if="course" class="hero card anim-pop">
      <div class="hero__text">
        <div class="hero__tags">
          <span class="badge badge--coral">{{ course.difficulty === 'BEGINNER' ? '零基础友好' : course.difficulty }}</span>
          <span class="badge badge--mint">{{ course.version }}</span>
          <span class="badge badge--sun">{{ course.totalLessons }} 课时</span>
        </div>
        <h1 class="hero__title title-round">{{ course.title }}</h1>
        <p class="hero__sub">{{ course.subtitle }}</p>
        <p class="hero__desc">{{ course.description }}</p>
        <div class="hero__actions">
          <RouterLink v-if="modules[0]?.lessons?.[0]" :to="`/lesson/${modules[0].lessons[0].slug}`" class="btn btn--primary btn--lg">
            开始第一节 →
          </RouterLink>
          <button class="btn btn--lilac btn--lg" @click="agent.open()">问鲸鲸一个问题</button>
        </div>
        <p class="hero__by">授课：{{ course.instructor }}</p>
      </div>
      <img src="/assets/agent/agent-happy.png" alt="鲸鲸" class="hero__img anim-float" />
    </section>

    <div v-if="loading" class="home__loading"><div class="spinner" /></div>

    <!-- 学习总览 -->
    <section v-else-if="progress.hasProgress" class="overview card anim-pop">
      <div class="overview__ring" :style="{ '--pct': `${overallPct * 3.6}deg` }">
        <span class="overview__pct">{{ overallPct }}%</span>
      </div>
      <div class="overview__body">
        <h3 class="title-round overview__title">继续加油喵~</h3>
        <p class="overview__sub">
          已完成 <strong>{{ progress.summary.completed }}</strong> / {{ progress.summary.totalLessons }} 节
          <template v-if="progress.summary.inProgress"> · 在学 {{ progress.summary.inProgress }} 节</template>
          <template v-if="progress.summary.favoriteCount"> · 收藏 {{ progress.summary.favoriteCount }} 节</template>
          <template v-if="progress.learningMinutes"> · 累计 {{ progress.learningMinutes }} 分钟</template>
        </p>
        <RouterLink v-if="progress.items.length" :to="`/lesson/${progress.items[0].slug}`" class="btn btn--sm btn--primary">
          接着看《{{ progress.items[0].title }}》
        </RouterLink>
      </div>
      <img src="/assets/agent/agent-idle.png" alt="鲸鲸" class="overview__whale anim-float" />
    </section>

    <!-- 课程目录 -->
    <section v-else class="catalog">
      <div class="section-head">
        <span class="dot" />
        <h2>课程目录</h2>
        <span class="line" />
        <span class="badge badge--lilac">{{ modules.length }} 个模块</span>
      </div>

      <div class="catalog__list">
        <article
          v-for="(m, mi) in modules"
          :key="m.id"
          class="mod card card--hover"
          :style="{ animationDelay: `${mi * 60}ms` }"
        >
          <header class="mod__head" @click="toggle(m.id)">
            <span class="mod__icon">{{ ICONS[m.icon] || '📘' }}</span>
            <div class="mod__meta">
              <h3 class="mod__title title-round">
                <span class="mod__no">{{ String(mi + 1).padStart(2, '0') }}</span>
                {{ m.title }}
              </h3>
              <p class="mod__summary">{{ m.summary }}</p>
            </div>
            <span class="mod__count badge badge--mint">{{ m.lessonCount }} 节</span>
            <span class="mod__arrow" :class="{ 'is-open': openModules[m.id] }">▾</span>
          </header>

          <!-- 课时列表 -->
          <Transition name="expand">
            <ul v-if="openModules[m.id]" class="mod__lessons">
              <li v-for="(l, li) in m.lessons || []" :key="l.id">
                <RouterLink :to="`/lesson/${l.slug}`" class="lesson-link">
                  <span class="lesson-link__no" :class="{ 'is-done': progress.isCompleted(l.id) }">
                    {{ progress.isCompleted(l.id) ? '✓' : li + 1 }}
                  </span>
                  <span class="lesson-link__title">{{ l.title }}</span>
                  <span class="lesson-link__sum">{{ l.summary }}</span>
                  <span v-if="progress.isFavorite(l.id)" class="lesson-link__fav">★</span>
                  <span class="lesson-link__go">→</span>
                </RouterLink>
              </li>
              <li v-if="!(m.lessons || []).length" class="mod__empty">课时加载中…</li>
            </ul>
          </Transition>

          <footer class="mod__foot">
            <button class="btn btn--sm btn--ghost" @click="askAbout(m)">🐳 让鲸鲸讲讲这个模块</button>
          </footer>
        </article>
      </div>
    </section>
  </div>
</template>

<style scoped>
.home { padding-top: var(--space-lg); }

/* Hero */
.hero {
  display: grid;
  grid-template-columns: 1.6fr 1fr;
  gap: var(--space-lg);
  align-items: center;
  padding: 36px;
  background: linear-gradient(135deg, var(--c-paper) 60%, var(--c-cream-deep));
}
.hero__tags { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 14px; }
.hero__title { margin: 0; font-size: 40px; font-weight: 800; }
.hero__sub { margin: 8px 0 14px; font-size: 17px; font-weight: 700; color: var(--c-coral-deep); }
.hero__desc { margin: 0 0 22px; font-size: 15px; line-height: 1.9; color: var(--c-ink-soft); }
.hero__actions { display: flex; gap: 12px; flex-wrap: wrap; }
.hero__by { margin: 18px 0 0; font-size: 13px; color: var(--c-ink-faint); }
.hero__img { width: 230px; height: 230px; justify-self: center; filter: drop-shadow(5px 7px 0 rgba(45,53,97,.18)); }

.home__loading { display: grid; place-items: center; padding: 70px 0; }

/* 学习总览 */
.overview {
  display: flex;
  align-items: center;
  gap: var(--space-lg);
  padding: 24px 28px;
  margin-top: var(--space-md);
  background: linear-gradient(120deg, var(--c-paper), var(--c-cream-deep));
}
.overview__ring {
  width: 96px; height: 96px;
  flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 50%;
  background: conic-gradient(var(--c-coral) var(--pct), var(--c-cream-deep) 0);
  border: var(--bw-base) solid var(--c-line);
  position: relative;
}
.overview__ring::after {
  content: '';
  position: absolute;
  inset: 11px;
  background: var(--c-paper);
  border-radius: 50%;
}
.overview__pct {
  position: relative;
  z-index: 1;
  font-family: var(--font-round);
  font-size: 20px;
  font-weight: 800;
}
.overview__body { flex: 1; min-width: 0; }
.overview__title { margin: 0 0 6px; font-size: 21px; }
.overview__sub { margin: 0 0 12px; font-size: 13.5px; color: var(--c-ink-soft); }
.overview__sub strong { color: var(--c-coral-deep); font-size: 16px; }
.overview__whale { width: 92px; height: 92px; flex-shrink: 0; }

/* 目录 */
.catalog { margin-top: var(--space-xl); }
.catalog__list { display: flex; flex-direction: column; gap: 18px; }

.mod { padding: 0; overflow: hidden; animation: pop-in .4s both; }
.mod__head {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px 22px;
  cursor: pointer;
}
.mod__icon {
  width: 52px; height: 52px;
  display: grid; place-items: center;
  font-size: 26px;
  background: var(--c-sun);
  border: var(--bw-base) solid var(--c-line);
  border-radius: var(--radius-md);
  flex-shrink: 0;
}
.mod__meta { flex: 1; min-width: 0; }
.mod__title { margin: 0 0 4px; font-size: 21px; }
.mod__no {
  display: inline-block;
  margin-right: 8px;
  font-size: 14px;
  color: var(--c-coral);
}
.mod__summary { margin: 0; font-size: 13px; color: var(--c-ink-faint); }
.mod__count { flex-shrink: 0; }
.mod__arrow {
  font-size: 20px;
  color: var(--c-ink-faint);
  transition: transform .2s;
  flex-shrink: 0;
}
.mod__arrow.is-open { transform: rotate(180deg); color: var(--c-coral); }

.mod__lessons {
  margin: 0;
  padding: 0 22px 8px;
  list-style: none;
  border-top: var(--bw-thin) dashed var(--c-ink-faint);
  padding-top: 12px;
}
.lesson-link {
  display: grid;
  grid-template-columns: 34px 1.3fr 2fr auto 24px;
  align-items: center;
  gap: 12px;
  padding: 11px 14px;
  margin-bottom: 6px;
  text-decoration: none;
  color: var(--c-ink);
  background: var(--c-cream);
  border: var(--bw-thin) solid transparent;
  border-radius: var(--radius-md);
  transition: all .16s;
}
.lesson-link__no.is-done { background: var(--c-mint); color: #fff; }
.lesson-link__fav { color: var(--c-sun-deep); font-size: 15px; }
.lesson-link:hover {
  background: var(--c-sun);
  border-color: var(--c-line);
  transform: translateX(4px);
  box-shadow: var(--shadow-sm);
}
.lesson-link__no {
  display: grid; place-items: center;
  width: 28px; height: 28px;
  font-family: var(--font-round);
  font-size: 13px; font-weight: 700;
  background: var(--c-paper);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: 50%;
}
.lesson-link__title { font-family: var(--font-round); font-weight: 700; }
.lesson-link__sum { font-size: 12px; color: var(--c-ink-faint); }
.lesson-link__go { color: var(--c-coral); font-weight: 700; }
.mod__empty { padding: 14px; font-size: 13px; color: var(--c-ink-faint); text-align: center; }

.mod__foot { padding: 0 22px 18px; }

.expand-enter-active, .expand-leave-active { transition: opacity .2s ease, max-height .25s ease; overflow: hidden; }
.expand-enter-from, .expand-leave-to { opacity: 0; max-height: 0; }
.expand-enter-to, .expand-leave-from { max-height: 900px; }

@media (max-width: 900px) {
  .hero { grid-template-columns: 1fr; padding: 24px; }
  .hero__title { font-size: 30px; }
  .hero__img { width: 160px; height: 160px; }
  .lesson-link { grid-template-columns: 30px 1fr 20px; }
  .lesson-link__sum { display: none; }
}
</style>