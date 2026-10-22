<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAgentStore } from '@/stores/agent'
import { errMsg } from '@/api/http'

const auth = useAuthStore()
const agent = useAgentStore()
const router = useRouter()
const route = useRoute()

const mode = ref<'login' | 'register'>('login')
const username = ref('')
const password = ref('')
const nickname = ref('')
const loading = ref(false)
const error = ref('')

const MEMES = [
  '/assets/agent/meme-ciallo.png',
  '/assets/agent/meme-cute.png',
  '/assets/agent/meme-oh.png',
  '/assets/agent/meme-amazing.png',
]
const meme = ref(MEMES[0])

function switchMode() {
  mode.value = mode.value === 'login' ? 'register' : 'login'
  error.value = ''
  meme.value = MEMES[Math.floor(Math.random() * MEMES.length)]
}

async function submit() {
  error.value = ''
  if (username.value.trim().length < 3) return void (error.value = '用户名至少 3 个字符')
  if (password.value.length < 6) return void (error.value = '密码至少 6 位')
  loading.value = true
  try {
    if (mode.value === 'login') {
      await auth.login(username.value.trim(), password.value)
    } else {
      await auth.register(username.value.trim(), password.value, nickname.value.trim())
    }
    await agent.loadProfile()
    const redirect = (route.query.redirect as string) || '/'
    router.push(redirect)
  } catch (e) {
    error.value = errMsg(e)
    // 失败时抖一下
    const el = document.querySelector('.login__card') as HTMLElement | null
    if (el) {
      el.style.animation = 'shake .4s'
      setTimeout(() => (el.style.animation = ''), 450)
    }
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  meme.value = MEMES[Math.floor(Math.random() * MEMES.length)]
})
</script>

<template>
  <div class="login">
    <div class="login__deco">
      <span class="blob blob--1" /><span class="blob blob--2" /><span class="blob blob--3" />
    </div>

    <div class="login__inner">
      <!-- 左：品牌介绍 -->
      <section class="login__intro">
        <img :src="meme" class="login__meme anim-float" alt="鲸鲸" />
        <h1 class="login__headline title-round">
          Java 精通之路
          <span class="login__headline-sub">从 Hello World 到高并发架构</span>
        </h1>
        <p class="login__desc">
          6 个模块 · 42 节课 · 每节配可运行代码与原理剖析。<br />
          鲸鲸 AI 助教全程陪跑，问它就不怕卡壳喵～
        </p>
        <div class="login__tags">
          <span class="badge badge--coral">卡通课堂</span>
          <span class="badge badge--mint">鲸鲸助教</span>
          <span class="badge badge--sun">KingBase 驱动</span>
          <span class="badge badge--lilac">Spring Boot 3</span>
        </div>
      </section>

      <!-- 右：登录表单 -->
      <section class="login__card card">
        <header class="login__card-head">
          <h2 class="title-round">{{ mode === 'login' ? '欢迎回来' : '加入我们' }}</h2>
          <p class="login__hint">
            {{ mode === 'login' ? '登录后即可保存学习进度、收藏课时' : '注册一个账号开始学习吧' }}
          </p>
        </header>

        <form class="login__form" @submit.prevent="submit">
          <label class="login__field">
            <span>用户名</span>
            <input v-model="username" class="input" placeholder="3~32 个字符" autocomplete="username" />
          </label>

          <label v-if="mode === 'register'" class="login__field">
            <span>昵称</span>
            <input v-model="nickname" class="input" placeholder="怎么称呼你？（选填）" />
          </label>

          <label class="login__field">
            <span>密码</span>
            <input
              v-model="password"
              class="input"
              type="password"
              placeholder="至少 6 位"
              :autocomplete="mode === 'login' ? 'current-password' : 'new-password'"
            />
          </label>

          <p v-if="error" class="login__error">⚠ {{ error }}</p>

          <button class="btn btn--primary btn--lg login__submit" type="submit" :disabled="loading">
            <span v-if="loading" class="spinner login__spin" />
            {{ mode === 'login' ? '登录' : '注册并登录' }}
          </button>
        </form>

        <footer class="login__foot">
          <span>{{ mode === 'login' ? '还没有账号？' : '已有账号？' }}</span>
          <button class="btn btn--sm btn--ghost" @click="switchMode">
            {{ mode === 'login' ? '去注册' : '去登录' }}
          </button>
        </footer>

        <p class="login__demo">演示账号：admin / demo，密码 123456</p>
      </section>
    </div>
  </div>
</template>

<style scoped>
.login {
  position: relative;
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: var(--space-lg) var(--space-md);
  overflow: hidden;
}
.login__deco { position: absolute; inset: 0; pointer-events: none; }
.blob { position: absolute; border-radius: 50%; filter: blur(2px); }
.blob--1 { width: 220px; height: 220px; background: rgba(78,205,196,.35); top: 8%; left: 6%; animation: float-y 5s ease-in-out infinite; }
.blob--2 { width: 180px; height: 180px; background: rgba(255,217,61,.35); bottom: 10%; right: 8%; animation: float-y 6.2s ease-in-out infinite reverse; }
.blob--3 { width: 150px; height: 150px; background: rgba(255,107,107,.28); top: 55%; left: 42%; animation: float-y 4.4s ease-in-out infinite; }

.login__inner {
  position: relative;
  display: grid;
  grid-template-columns: 1.1fr 1fr;
  gap: var(--space-xl);
  align-items: center;
  width: 100%;
  max-width: 1020px;
}

.login__intro { text-align: center; }
.login__meme {
  width: 190px; height: 190px;
  margin-bottom: 18px;
  filter: drop-shadow(4px 6px 0 rgba(45,53,97,.2));
}
.login__headline { margin: 0; font-size: 42px; font-weight: 800; line-height: 1.2; }
.login__headline-sub {
  display: block;
  margin-top: 8px;
  font-size: 17px;
  font-weight: 700;
  color: var(--c-coral-deep);
}
.login__desc { margin: 18px 0 20px; font-size: 15px; line-height: 1.9; color: var(--c-ink-soft); }
.login__tags { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; }

.login__card { padding: 32px; }
.login__card-head { margin-bottom: 22px; }
.login__card-head h2 { margin: 0 0 6px; font-size: 27px; }
.login__hint { margin: 0; font-size: 13px; color: var(--c-ink-faint); }

.login__form { display: flex; flex-direction: column; gap: 16px; }
.login__field { display: flex; flex-direction: column; gap: 6px; }
.login__field span { font-family: var(--font-round); font-size: 13px; font-weight: 700; }
.login__error {
  margin: 0;
  padding: 9px 13px;
  font-size: 13px;
  color: #fff;
  background: var(--c-coral);
  border: var(--bw-thin) solid var(--c-line);
  border-radius: var(--radius-sm);
  animation: shake .35s;
}
.login__submit { justify-content: center; width: 100%; }
.login__spin { width: 20px; height: 20px; border-width: 3px; border-top-color: #fff; border-color: rgba(255,255,255,.4); }

.login__foot {
  margin-top: 22px;
  padding-top: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  border-top: var(--bw-thin) dashed var(--c-ink-faint);
  font-size: 14px;
  color: var(--c-ink-soft);
}
.login__demo {
  margin: 14px 0 0;
  text-align: center;
  font-size: 12px;
  color: var(--c-ink-faint);
}

@media (max-width: 880px) {
  .login__inner { grid-template-columns: 1fr; gap: var(--space-lg); }
  .login__meme { width: 140px; height: 140px; }
  .login__headline { font-size: 32px; }
}
</style>