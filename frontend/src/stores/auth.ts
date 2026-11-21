import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi } from '@/api'
import { getToken, setToken, clearToken } from '@/api/http'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(getToken())
  const user = ref<any>(null)
  const ready = ref(false)
  const profileUnavailable = ref(false)

  const isLogged = computed(() => !!token.value)
  const displayName = computed(() => user.value?.nickname || user.value?.username || '同学')
  const isAdmin = computed(() => (user.value?.role || '').toUpperCase() === 'ADMIN')

  /** 应用启动时用本地 token 换取用户信息 */
  async function bootstrap() {
    const requestedToken = token.value
    if (!requestedToken) {
      profileUnavailable.value = false
      ready.value = true
      return
    }
    const currentSession = () => token.value === requestedToken && getToken() === requestedToken
    try {
      const profile = await authApi.me(requestedToken)
      if (currentSession()) {
        user.value = profile
        profileUnavailable.value = false
      }
    } catch {
      // 401 由 HTTP 拦截器处理。临时故障保留现有会话，允许重试资料读取。
      if (currentSession()) profileUnavailable.value = true
    } finally {
      if (currentSession()) ready.value = true
    }
  }

  async function syncStoredSession() {
    const storedToken = getToken()
    if (storedToken === token.value) return
    user.value = null
    profileUnavailable.value = false
    ready.value = false
    token.value = storedToken
    await bootstrap()
  }

  async function login(username: string, password: string) {
    const r = await authApi.login(username, password)
    setToken(r.token)
    token.value = r.token
    user.value = r.user
    profileUnavailable.value = false
    ready.value = true
    return r.user
  }

  async function register(username: string, password: string, nickname: string) {
    const r = await authApi.register(username, password, nickname)
    setToken(r.token)
    token.value = r.token
    user.value = r.user
    profileUnavailable.value = false
    ready.value = true
    return r.user
  }

  async function logout() {
    const oldToken = token.value
    if (!oldToken) return
    if (getToken() !== oldToken) {
      await syncStoredSession()
      return
    }
    try {
      await authApi.logout(oldToken)
    } catch {
      // 即使服务端失败也要清本地
    }
    if (token.value === oldToken && getToken() === oldToken) invalidateSession()
  }

  function invalidateSession() {
    clearToken()
    user.value = null
    token.value = ''
    profileUnavailable.value = false
    ready.value = true
  }

  return { token, user, ready, profileUnavailable, isLogged, displayName, isAdmin, bootstrap, login, register, logout, syncStoredSession }
})
