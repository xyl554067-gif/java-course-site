import axios, { type AxiosInstance } from 'axios'

/** 后端统一响应包装 */
export interface ApiResult<T = any> {
  code: number
  message: string
  data: T
}

export const TOKEN_KEY = 'javacourse_token'
export const AUTH_EXPIRED_EVENT = 'javacourse:auth-expired'

export function getToken(): string {
  return localStorage.getItem(TOKEN_KEY) || ''
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token)
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY)
}

/**
 * API 基址解析优先级：
 *   1. 运行时 window.__APP_CONFIG__.apiBase —— GitHub Pages 运维直接改 config.js
 *      即可切换后端，无需重新构建。
 *   2. 构建期 VITE_API_BASE_URL —— CI 里注入。
 *   3. 默认 '/api' —— 本地 dev（Vite 代理）与前后端同域部署。
 *
 * 注意：Pages 子路径部署时 '/api' 会解析到域名根（https://user.github.io/api），
 * 因此静态部署务必通过 config.js 或 VITE_API_BASE_URL 指定真实后端地址。
 */
function resolveApiBase(): string {
  // Local development always uses the Vite proxy to the local backend. The runtime
  // config is for the static GitHub Pages deployment and must not divert localhost.
  if (import.meta.env.DEV) return '/api'
  const runtime = (window as any).__APP_CONFIG__?.apiBase
  if (typeof runtime === 'string') return runtime
  const buildTime = import.meta.env.VITE_API_BASE_URL as string | undefined
  if (buildTime) return buildTime
  return '/api'
}

const API_BASE_URL = resolveApiBase()

/** 导出解析后的基址，供需要绕过 axios 的场景（如页面卸载时的 keepalive 请求）使用 */
export { API_BASE_URL }

const http: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
})

http.interceptors.request.use((config) => {
  const token = getToken()
  if (token && !config.headers.has('Authorization')) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

http.interceptors.response.use(
  (resp) => resp.data,
  (error) => {
    const token = getToken()
    // A late response must not log out a newer session.
    if (error?.response?.status === 401 && token && error?.config?.headers?.Authorization === `Bearer ${token}`) {
      clearToken()
      window.dispatchEvent(new Event(AUTH_EXPIRED_EVENT))
      if (!location.hash.includes('/login')) {
        location.hash = '#/login'
      }
    }
    return Promise.reject(error)
  },
)

/** 拆包统一响应，失败时抛出后端给的中文提示 */
export async function request<T = any>(promise: Promise<ApiResult<T>>): Promise<T> {
  const res = await promise
  if (res.code !== 200) {
    throw new Error(res.message || '请求失败')
  }
  return res.data
}

/** 把请求错误转成可展示的中文文案 */
export function errMsg(e: unknown): string {
  if (axios.isAxiosError<{ message?: string }>(e)) {
    const message = e.response?.data?.message
    if (message) return message
    if (e.code === 'ECONNABORTED' || e.code === 'ETIMEDOUT') return '等待服务器响应超时，请稍后重试'
    if (!e.response || e.response.status >= 500) return '暂时无法连接服务器，请稍后重试'
  }
  return e instanceof Error ? e.message : '请求失败，请稍后重试'
}

export default http
