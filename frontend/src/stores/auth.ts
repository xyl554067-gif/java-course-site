import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi } from '@/api'
import { getToken, setToken, clearToken } from '@/api/http'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(getToken())
  const user = ref<any>(null)
  const ready = ref(false)

  const isLogged = computed(() => !!token.value)
  const displayName = computed(() => user.value?.nickname || user.value?.username || '同学')
  const isAdmin = computed(() => (user.value?.role || '').toUpperCase() === 'ADMIN')

  /** 应用启动时用本地 token 换取用户信息 */
  async function bootstrap() {
    if (!token.value) {
      ready.value = true
      return
    }
    try {
      user.value = await authApi.me()
    } catch {
      token.value = ''
      clearToken()
    } finally {
      ready.value = true
    }
  }

  async function login(username: string, password: string) {
    const r = await authApi.login(username, password)
    token.value = r.token
    setToken(r.token)
    user.value = r.user
    return r.user
  }

  async function register(username: string, password: string, nickname: string) {
    const r = await authApi.register(username, password, nickname)
    token.value = r.token
    setToken(r.token)
    user.value = r.user
    return r.user
  }

  async function logout() {
    try {
      await authApi.logout()
    } catch {
      // 即使服务端失败也要清本地
    }
    token.value = ''
    user.value = null
    clearToken()
  }

  return { token, user, ready, isLogged, displayName, isAdmin, bootstrap, login, register, logout }
})